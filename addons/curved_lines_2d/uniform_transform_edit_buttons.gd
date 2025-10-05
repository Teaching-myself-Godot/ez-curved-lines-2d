@tool
extends Control

signal mode_changed(mode : CurvedLines2D.UniformTransformMode)
signal flip_horizontal()
signal flip_vertical()


func enable() -> void:
	show()
	%DefaultEdit.button_pressed = true


func _on_default_edit_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.UniformTransformMode.NONE)


func _on_uniform_translate_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.UniformTransformMode.TRANSLATE)


func _on_uniform_rotate_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.UniformTransformMode.ROTATE)


func _on_uniform_scale_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.UniformTransformMode.SCALE)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).is_command_or_control_pressed():
			return
		if (event as InputEventKey).keycode == KEY_Z:
			%UniformTranslate.button_pressed = true
		if (event as InputEventKey).keycode == KEY_X:
			%UniformRotate.button_pressed = true
		if (event as InputEventKey).keycode == KEY_C:
			%UniformScale.button_pressed = true


func _on_flip_horizontal_pressed() -> void:
	flip_horizontal.emit()


func _on_flip_vertical_pressed() -> void:
	flip_vertical.emit()
