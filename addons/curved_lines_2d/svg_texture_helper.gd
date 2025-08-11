@tool
class_name SVGTextureHelper
extends Node

@export var svg_resource: SVGResource : set = _set_svg_resource
@export var target_property: String = "texture" ## e.g., "icon", "texture", "theme_override_icon"

## Downscales the render target to improve performance at the cost of quality.
## 1 = No downscaling (best quality). 2 = Render at half size. 10 = Render at 1/10th size.
@export_range(1.0, 20.0, 0.1) var render_downscale_factor: float = 10.0 # For memory safety

var _parent_control: Control

func _ready() -> void:
	# Ensure the parent is a Control node.
	_parent_control = get_parent() as Control
	if not _parent_control:
		push_error("SVGTextureHelper must be a child of a Control node.")
		queue_free()
		return

	# Connect to the parent's resize signal to trigger re-renders.
	_parent_control.resized.connect(_queue_render)

	# Perform initial render if we have a resource.
	if svg_resource:
		_queue_render()

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
		# Set the new texture on the parent control
		_parent_control.set_deferred(target_property, new_texture)

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
