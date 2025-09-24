@tool
extends Control

signal mode_changed(mode : CurvedLines2D.UniformTransformMode)

func enable(shape_type : ScalableVectorShape2D.ShapeType) -> void:
	show()
	%DefaultEdit.button_pressed = true
	if shape_type == ScalableVectorShape2D.ShapeType.PATH:
		%UniformRotate.disabled = false
		%UniformScale.disabled = false
	else:
		%UniformRotate.disabled = true
		%UniformScale.disabled = true


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
		if (event as InputEventKey).keycode == KEY_X and not %UniformRotate.disabled:
			%UniformRotate.button_pressed = true
		if (event as InputEventKey).keycode == KEY_C and not %UniformScale.disabled:
			%UniformScale.button_pressed = true
