@tool
extends Node

class_name SVGTextureHelper

# May use a class name if clutter is not a concern
# Map property names → default values
const PROPERTY_MAPPINGS: Dictionary = {
	"expand_mode": TextureRect.EXPAND_IGNORE_SIZE,
	"expand_icon": true,
	"ignore_texture_size": true
}

@export var svg_resource := SVGResource.new(): set = _set_svg_resource
@export var target_property: String = "" : set = _set_target_property

var _available_texture_properties: Array[String] = []
var _is_saving_scene: bool = false
var _cached_texture: Texture2D  # Store the actual texture to restore after save

func _ready() -> void:
	# Ensure the parent is a Control node.
	if not get_parent() is Control:
		push_error("SVGTextureHelper must be a child of a Control node.")
		queue_free()
		return

	# Detect available texture properties
	_detect_texture_properties()

	# Auto-select first available property if none is set
	if target_property.is_empty() and not _available_texture_properties.is_empty():
		target_property = _available_texture_properties[0]

	# Connect to the parent's resize signal to trigger re-renders.
	get_parent().resized.connect(_queue_render)

	# Change parent texture properties
	_update_parent_properties()

	# Connect to save signals if in editor
	if Engine.is_editor_hint():
		_connect_save_signals()

	# Perform initial render if we have a resource.
	if svg_resource:
		_queue_render()

func _connect_save_signals() -> void:
	if Engine.is_editor_hint():
		if get_tree():
			get_tree().node_configuration_warning_changed.connect(_on_scene_tree_changed)


func _on_editor_visibility_changed() -> void:
	# This is a heuristic that often correlates with save operations
	if Engine.is_editor_hint():
		_prepare_for_potential_save()

func _on_scene_tree_changed(node: Node) -> void:
	# Another heuristic for detecting editor operations that might include saving
	if Engine.is_editor_hint() and is_ancestor_of(node):
		_prepare_for_potential_save()

# Override the notification method to catch save notifications
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			_prepare_for_save()
		NOTIFICATION_EDITOR_POST_SAVE:
			_restore_after_save()
		# Also catch when the node is about to be saved
		NOTIFICATION_WM_CLOSE_REQUEST:
			if Engine.is_editor_hint():
				_prepare_for_save()

func _prepare_for_potential_save() -> void:
	# Use a timer to briefly set texture to null, then restore
	# This catches most save scenarios
	if _is_saving_scene:
		return

	_prepare_for_save()
	# Restore after a brief delay
	get_tree().create_timer(0.1).timeout.connect(_restore_after_save, CONNECT_ONE_SHOT)

func _prepare_for_save() -> void:
	if not Engine.is_editor_hint() or not get_parent() or target_property.is_empty():
		return

	if not _has_property(get_parent(), target_property):
		return

	_is_saving_scene = true

	# Store the current texture
	_cached_texture = get_parent().get(target_property) as Texture2D

	# Set texture to null to prevent it from being saved
	get_parent().set(target_property, null)

	print_rich("[color=yellow]SVGTextureHelper: Texture temporarily set to null for saving[/color]")

func _restore_after_save() -> void:
	if not Engine.is_editor_hint() or not _is_saving_scene:
		return

	_is_saving_scene = false

	# Restore the cached texture
	if get_parent() and not target_property.is_empty() and _cached_texture:
		if _has_property(get_parent(), target_property):
			get_parent().set(target_property, _cached_texture)
			print_rich("[color=green]SVGTextureHelper: Texture restored after save[/color]")

	# Clear the cache
	_cached_texture = null

func _detect_texture_properties() -> void:
	_available_texture_properties.clear()

	if not get_parent():
		return

	# Get all properties from the parent control
	var property_list = get_parent().get_property_list()

	for prop_info in property_list:
		var prop_name: String = prop_info.name
		var prop_type = prop_info.type
		var prop_class_name = prop_info.class_name

		# Check if this property accepts a Texture2D
		# This covers properties with type TYPE_OBJECT and class_name "Texture2D"
		# or properties that are explicitly documented as texture properties
		if (prop_type == TYPE_OBJECT and
			(prop_class_name == "Texture2D" or
			 prop_class_name == "Texture" or
			 prop_class_name == "ImageTexture" or
			 prop_class_name == "CompressedTexture2D")):
			_available_texture_properties.append(prop_name)
		# Also check for commonly named texture properties
		elif (prop_name.to_lower().contains("texture") or
			  prop_name.to_lower().contains("icon") or
			  prop_name in ["normal", "pressed", "hover", "disabled", "focused"]):
			# Verify it can actually accept a texture by checking if it's an Object type
			if prop_type == TYPE_OBJECT:
				_available_texture_properties.append(prop_name)

	# Sort alphabetically for better UX
	_available_texture_properties.sort()

	# Ensure we have at least some common fallbacks
	if _available_texture_properties.is_empty():
		# Add common texture property names as fallbacks
		var common_properties = ["texture", "icon", "normal", "pressed"]
		for prop in common_properties:
			if _has_property(get_parent(), prop):
				_available_texture_properties.append(prop)


func _set_target_property(new_property: String) -> void:
	if target_property == new_property:
		return

	target_property = new_property

	# Re-apply texture if we have one
	if svg_resource and svg_resource.texture and get_parent():
		_on_texture_updated(svg_resource.texture)

func _update_parent_properties() -> void:
	if get_parent() == null:
		return

	for prop in PROPERTY_MAPPINGS.keys():
		if _has_property(get_parent(), prop):
			get_parent().set(prop, PROPERTY_MAPPINGS[prop])

func _has_property(target: Object, prop_name: StringName) -> bool:
	for info in target.get_property_list():
		if info.name == prop_name:
			return true
	return false

func _set_svg_resource(new_resource: SVGResource) -> void:
	if svg_resource == new_resource:
		return

	# Disconnect from old resource if it exists
	if svg_resource:
		if svg_resource.is_connected("texture_updated", _on_texture_updated):
			svg_resource.texture_updated.disconnect(_on_texture_updated)
		# Disconnect from the changed signal
		if svg_resource.is_connected("changed", _on_resource_changed):
			svg_resource.changed.disconnect(_on_resource_changed)

	svg_resource = new_resource

	if svg_resource:
		svg_resource.texture_updated.connect(_on_texture_updated)
		# CONNECT TO THE CHANGED SIGNAL
		svg_resource.changed.connect(_on_resource_changed)

		# If the resource already has a texture, apply it immediately.
		if svg_resource.texture:
			_on_texture_updated(svg_resource.texture)

		# Queue a render to ensure it's the correct size.
		_queue_render()

# Handles resource changes
func _on_resource_changed() -> void:
	# This gets called when svg_file_path or render_scale changes
	_queue_render()

func _on_texture_updated(new_texture: Texture2D) -> void:
	if get_parent() and not target_property.is_empty():
		# Don't update texture if we're in the middle of a save operation
		if _is_saving_scene:
			_cached_texture = new_texture  # Update our cache instead
			return

		# Validate that the property exists before setting it
		if _has_property(get_parent(), target_property):
			# Set the new texture on the parent control
			get_parent().set_deferred(target_property, new_texture)
		else:
			push_warning("Property '%s' not found on parent node '%s'" % [target_property, get_parent().name])

## Called on resize or when the resource changes.
func _queue_render() -> void:
	if svg_resource == null or svg_resource.svg_string.is_empty():
		get_parent().set(target_property, null)
		return
	# Don't render during save operations
	if _is_saving_scene:
		return

	# Check for valid conditions before requesting a render.
	if not is_instance_valid(svg_resource) or not is_instance_valid(get_parent()):
		return

	if Engine.is_editor_hint() or get_tree():
		var target_size: Vector2i = get_parent().size
		var rescale_factor := 1.0
		# If parent size is invalid or zero, use a minimal 1x1 placeholder.
		# This prevents rendering a huge texture during initialization in the editor.
		# The 'resized' signal will trigger a correct render once the size is calculated.
		if target_size.x <= 0 or target_size.y <= 0:
			target_size = Vector2i(1, 1)

		var stretch_mode : TextureRect.StretchMode = get_parent().stretch_mode if "stretch_mode" in get_parent() else TextureRect.STRETCH_SCALE
		if (
			stretch_mode == TextureRect.StretchMode.STRETCH_KEEP or
			stretch_mode == TextureRect.StretchMode.STRETCH_TILE or
			stretch_mode == TextureRect.StretchMode.STRETCH_KEEP_CENTERED
		):
			rescale_factor = 1.0
		else:
			rescale_factor = (target_size.x / svg_resource.original_size.x) * svg_resource.render_scale

		var image := Image.new()
		var error := image.load_svg_from_string(Marshalls.base64_to_utf8(svg_resource.svg_string), rescale_factor)

		if error != OK:
			push_error("Failed to render SVG: " + str(error))
			return

		var image_texture := ImageTexture.create_from_image(image)
		if (
			stretch_mode == TextureRect.StretchMode.STRETCH_KEEP or
			stretch_mode == TextureRect.StretchMode.STRETCH_TILE or
			stretch_mode == TextureRect.StretchMode.STRETCH_KEEP_CENTERED
		):
			image_texture.set_size_override(svg_resource.original_size)
		else:
			get_parent().set(target_property, image_texture)


# Helper function to refresh the property list in the editor
func _refresh_properties() -> void:
	if Engine.is_editor_hint():
		_detect_texture_properties()
		notify_property_list_changed()

# Manual save preparation - you can call this from editor plugins or scripts
func manual_prepare_for_save() -> void:
	_prepare_for_save()

# Manual save restoration - you can call this from editor plugins or scripts
func manual_restore_after_save() -> void:
	_restore_after_save()
