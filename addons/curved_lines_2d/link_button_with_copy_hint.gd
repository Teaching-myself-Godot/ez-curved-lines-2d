@tool
extends LinkButton

func _set(property: StringName, value: Variant) -> bool:
	match property:
		"uri":
			uri = value
			_update_tooltip_text()
			return true
	return false


func _enter_tree() -> void:
	_update_tooltip_text()


func _update_tooltip_text():
	tooltip_text = "This link will open a webpage in your browser: " + uri
	tooltip_text += "\nRight click to copy this link"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		DisplayServer.clipboard_set(uri)
		if Engine.is_editor_hint():
			EditorInterface.get_editor_toaster().push_toast("Link copied!")
