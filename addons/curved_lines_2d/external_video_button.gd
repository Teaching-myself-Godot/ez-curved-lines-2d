@tool
extends PanelContainer

signal prop_updated()

@export var img : Texture2D:
	set(_img):
		img = _img
		prop_updated.emit()

@export var uri : String:
	set(_uri):
		uri = _uri
		prop_updated.emit()

@export var text : String:
	set(_text):
		text = _text
		prop_updated.emit()

var stylebox : StyleBoxFlat = preload("res://addons/curved_lines_2d/external_video_button.stylebox")
var stylebox_hover : StyleBoxFlat = preload("res://addons/curved_lines_2d/external_video_button_hover.stylebox")

func _enter_tree() -> void:
	if not prop_updated.is_connected(_on_prop_updated):
		prop_updated.connect(_on_prop_updated)
	_on_prop_updated()

func _on_prop_updated() -> void:
	%LinkButtonWithCopyHint.uri = uri
	%TextureButton.texture_normal = img
	%LinkButtonWithCopyHint.text = text
	%TextureButton.tooltip_text = %LinkButtonWithCopyHint.tooltip_text
	tooltip_text = %LinkButtonWithCopyHint.tooltip_text

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		OS.shell_open(uri)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		DisplayServer.clipboard_set(%LinkButtonWithCopyHint.uri)
		if Engine.is_editor_hint():
			EditorInterface.get_editor_toaster().push_toast("Link copied!")


func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", stylebox_hover)


func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", stylebox)

