@tool
extends PopupPanel

signal choice_confirmed()

var _dragging := false
var _drag_start := Vector2.ZERO


func _on_confirm_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%ImportingNormallyLabel.hide()
		%BottomCenterOriginCheckBox.show()
		%ReuseExistingAnimationPlayerCheckBox.show()
	else:
		%ImportingNormallyLabel.show()
		%BottomCenterOriginCheckBox.hide()
		%ReuseExistingAnimationPlayerCheckBox.hide()


func _on_ok_button_pressed() -> void:
	choice_confirmed.emit()
	hide()


func is_confirmed() -> bool:
	return %ConfirmCheckBox.button_pressed


func _on_panel_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _dragging:
				_dragging = true
				_drag_start = EditorInterface.get_base_control().get_local_mouse_position()
		else:
			_dragging = false
	if event is InputEventMouseMotion and _dragging:
		position += Vector2i(EditorInterface.get_base_control().get_local_mouse_position() - _drag_start)
		_drag_start = EditorInterface.get_base_control().get_local_mouse_position()

