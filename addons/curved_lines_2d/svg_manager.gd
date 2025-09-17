# Staric class that handles GUI SVGs
@tool
extends Node

# Cache: "resource_id_width_height_scale" -> Texture2D
static var _texture_cache: Dictionary = {} # Not yet implemented
static var _render_queue: Dictionary = {}
static var _render_thread: Thread
static var _mutex := Mutex.new()
static var _is_processing := false
static var _is_shutting_down := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_shutdown()

func _shutdown() -> void:
	_mutex.lock()
	_is_shutting_down = true
	_render_queue.clear()
	_mutex.unlock()

	# Wait for any running thread to complete
	if _render_thread and _render_thread.is_started():
		_render_thread.wait_to_finish()
		_render_thread = null

## The helper node calls this to request a render.
static func request_render(resource: SVGResource, target_size: Vector2i) -> void:
	_mutex.lock()
	if _is_shutting_down:
		_mutex.unlock()
		return
	_mutex.unlock()

	if not resource or resource.get_svg_string().is_empty() or target_size.x <= 0 or target_size.y <= 0:
		return

	_mutex.lock()
	_render_queue[resource] = target_size
	_mutex.unlock()

	_process_queue.call_deferred()

static func _process_queue() -> void:
	_mutex.lock()
	if _is_processing or _render_queue.is_empty() or _is_shutting_down:
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

static func _render_svg_threaded(data: Dictionary) -> void:
	var image := Image.new()
	var svg_string: String = data.svg_string
	var target_size: Vector2i = data.size
	var render_scale: float = data.scale

	var error := image.load_svg_from_string(svg_string, target_size.x * render_scale)

	if error != OK:
		push_error("Failed to render SVG: " + str(error))
		_on_render_complete.call_deferred(data.resource, null)
		return

	var image_texture := ImageTexture.create_from_image(image)
	_on_render_complete.call_deferred(data.resource, image_texture)

static func _on_render_complete(resource: SVGResource, new_texture: ImageTexture) -> void:
	_mutex.lock()
	if _is_shutting_down:
		_mutex.unlock()
		if _render_thread:
			_render_thread.wait_to_finish()
			_render_thread = null
		return
	_mutex.unlock()

	if resource and new_texture:
		resource._update_texture(new_texture)

	if _render_thread:
		_render_thread.wait_to_finish()
		_render_thread = null

	_mutex.lock()
	_is_processing = false
	_mutex.unlock()

	_process_queue.call_deferred()
