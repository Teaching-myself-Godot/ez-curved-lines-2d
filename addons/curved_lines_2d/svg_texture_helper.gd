@tool
class_name SVGTextureHelper
extends Node

# Map property names → default values
const PROPERTY_MAPPINGS: Dictionary = {
	"expand_mode": TextureRect.EXPAND_IGNORE_SIZE,
	"expand_icon": true,
	"ignore_texture_size": true
}

var svg_resource: SVGResource : set = _set_svg_resource
var target_property: String = "" : set = _set_target_property
var render_downscale_factor: float = 10.0

var _parent_control: Control
var _available_texture_properties: Array[String] = []

func _ready() -> void:
	# Ensure the parent is a Control node.
	_parent_control = get_parent() as Control
	if not _parent_control:
		push_error("SVGTextureHelper must be a child of a Control node.")
		queue_free()
		return

	# Detect available texture properties
	_detect_texture_properties()

	# Auto-select first available property if none is set
	if target_property.is_empty() and not _available_texture_properties.is_empty():
		target_property = _available_texture_properties[0]

	# Connect to the parent's resize signal to trigger re-renders.
	_parent_control.resized.connect(_queue_render)

	# Change parent texture properties
	_update_parent_properties()

	# Perform initial render if we have a resource.
	if svg_resource:
		_queue_render()

func _detect_texture_properties() -> void:
	_available_texture_properties.clear()

	if not _parent_control:
		return

	# Get all properties from the parent control
	var property_list = _parent_control.get_property_list()

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
			if _has_property(_parent_control, prop):
				_available_texture_properties.append(prop)

func _get_property_list() -> Array:
	var properties = []

	# SVG Resource property
	properties.append({
		"name": "svg_resource",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "SVGResource"
	})

	# Target property as dropdown if we have detected properties
	if not _available_texture_properties.is_empty():
		var hint_string = ",".join(_available_texture_properties)
		properties.append({
			"name": "target_property",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": hint_string
		})
	else:
		# Fallback to string input if no properties detected
		properties.append({
			"name": "target_property",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": ""
		})

	# Render downscale factor with range
	properties.append({
		"name": "render_downscale_factor",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1.0,20.0,0.1"
	})

	return properties

func _set_target_property(new_property: String) -> void:
	if target_property == new_property:
		return

	target_property = new_property

	# Re-apply texture if we have one
	if svg_resource and svg_resource.texture and _parent_control:
		_on_texture_updated(svg_resource.texture)

func _update_parent_properties() -> void:
	if _parent_control == null:
		return

	for prop in PROPERTY_MAPPINGS.keys():
		if _has_property(_parent_control, prop):
			_parent_control.set(prop, PROPERTY_MAPPINGS[prop])

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
	if _parent_control and not target_property.is_empty():
		# Validate that the property exists before setting it
		if _has_property(_parent_control, target_property):
			# Set the new texture on the parent control
			_parent_control.set_deferred(target_property, new_texture)
		else:
			push_warning("Property '%s' not found on parent node '%s'" % [target_property, _parent_control.name])

## Called on resize or when the resource changes.
func _queue_render() -> void:
	# Check for valid conditions before requesting a render.
	if not is_instance_valid(svg_resource) or not is_instance_valid(_parent_control):
		return

	if Engine.is_editor_hint() or get_tree():
		var target_size: Vector2i = _parent_control.size

		# If parent size is invalid or zero, use a minimal 1x1 placeholder.
		# This prevents rendering a huge texture during initialization in the editor.
		# The 'resized' signal will trigger a correct render once the size is calculated.
		if target_size.x <= 0 or target_size.y <= 0:
			target_size = Vector2i(1, 1)

		# Apply the configurable downscale factor.
		# We ensure the factor is at least 1 to avoid division by zero or upsizing.
		var final_size = target_size / max(1.0, render_downscale_factor)
		SVGManager.request_render(svg_resource, final_size)

# Helper function to refresh the property list in the editor
func _refresh_properties() -> void:
	if Engine.is_editor_hint():
		_detect_texture_properties()
		notify_property_list_changed()
