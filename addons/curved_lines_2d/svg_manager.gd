# Autoload script that handles GUI SVGs
@tool
extends Node

# Cache: "resource_id_width_height_scale" -> Texture2D
var _texture_cache: Dictionary = {} # Not yet implemented
var _render_queue: Dictionary = {}
var _render_thread: Thread
var _mutex := Mutex.new()
var _is_processing := false

## The helper node calls this to request a render.
func request_render(resource: SVGResource, target_size: Vector2i) -> void:
	if not resource or resource.get_svg_string().is_empty() or target_size.x <= 0 or target_size.y <= 0:
		return

	_mutex.lock()
	_render_queue[resource] = target_size
	_mutex.unlock()

	call_deferred("_process_queue")

func _process_queue() -> void:
	_mutex.lock()
	if _is_processing or _render_queue.is_empty():
		_mutex.unlock()
		return

	_is_processing = true

	# Get the first key (resource), then get its value (size), then remove the entry.
	var resource: SVGResource = _render_queue.keys().front()
	var target_size: Vector2i = _render_queue[resource]
	_render_queue.erase(resource)

	_mutex.unlock()

	# Prepare data for the thread. Pass the SVG content directly.
	var render_data := {
		"resource": resource,
		"svg_string": resource.get_svg_string(),
		"size": target_size,
		"scale": resource.render_scale
	}

	_render_thread = Thread.new()
	_render_thread.start(_render_svg_threaded.bind(render_data))

func _render_svg_threaded(data: Dictionary) -> void:
	var image := Image.new()
	var svg_string: String = data.svg_string
	var target_size: Vector2i = data.size
	var render_scale: float = data.scale

	var error := image.load_svg_from_string(svg_string, target_size.x * render_scale)

	if error != OK:
		push_error("Failed to render SVG: " + str(error))
		call_deferred("_on_render_complete", data.resource, null)
		return

	var image_texture := ImageTexture.create_from_image(image)
	call_deferred("_on_render_complete", data.resource, image_texture)

func _on_render_complete(resource: SVGResource, new_texture: ImageTexture) -> void:
	if resource and new_texture:
		resource._update_texture(new_texture)

	if _render_thread:
		_render_thread.wait_to_finish()
		_render_thread = null

	_mutex.lock()
	_is_processing = false
	_mutex.unlock()

	call_deferred("_process_queue")
