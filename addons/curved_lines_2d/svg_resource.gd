@tool
class_name SVGResource
extends Resource

## Emitted when the SVG texture has been rendered or re-rendered.
signal texture_updated(new_texture: Texture2D)

@export_file("*.svg") var svg_file_path: String = "" : set = _set_svg_file_path
@export var render_scale: float = 1.0 : set = _set_render_scale # I'd recommend rendering at half scale
@export var svg_string := ""
@export var original_size := Vector2.ZERO

var texture: Texture2D

func _set_svg_file_path(path: String) -> void:
	if Engine.is_editor_hint():
		if svg_file_path == path:
			return
		svg_file_path = path
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			svg_string = Marshalls.utf8_to_base64(file.get_as_text())
			var image := Image.new()
			var error := image.load_svg_from_string(Marshalls.base64_to_utf8(svg_string))
			if error != OK:
				push_error("Failed to render SVG: " + str(error))
				return
			original_size = image.get_size()
			file.close()
		else:
			svg_string = ""
			texture = null

	# Notify that the resource has changed. The helper will trigger a re-render.
	emit_changed()

func _set_render_scale(scale: float) -> void:
	if render_scale == scale:
		return
	render_scale = scale
	# Notify that the resource has changed. The helper will trigger a re-render.
	emit_changed()

## Internal method called by the manager upon render completion.
func _update_texture(new_texture: Texture2D) -> void:
	texture = new_texture
	texture_updated.emit(texture)
	# Notify the editor that this resource has changed, so it updates the inspector.
	emit_changed()
