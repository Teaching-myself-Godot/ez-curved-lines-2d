@tool
extends HBoxContainer

signal mode_changed(mode : CurvedLines2D.SVSEditMode)
signal flip_horizontal()
signal flip_vertical()

func show_svs_editors(has_skeleton) -> void:
	%UniformRotate.show()
	%UniformTranslate.show()
	%UniformScale.show()
	%FlipHorizontal.show()
	%FlipVertical.show()
	%PaintBone.show()
	%VSeparator1.show()
	%VSeparator2.show()


func hide_svs_editors() -> void:
	%UniformRotate.hide()
	%UniformTranslate.hide()
	%UniformScale.hide()
	%FlipHorizontal.hide()
	%FlipVertical.hide()
	%PaintBone.hide()
	%VSeparator1.hide()
	%VSeparator2.hide()


func set_default_mode(svs_is_selected := false) -> void:
	%DefaultEdit.button_pressed = true


func _on_default_edit_toggled(toggled_on: bool) -> void:
	if toggled_on:
		print("TODO: make distinction between point edit and no point edit")
		mode_changed.emit(CurvedLines2D.SVSEditMode.NONE)


func _on_uniform_translate_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.SVSEditMode.TRANSLATE)


func _on_uniform_rotate_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.SVSEditMode.ROTATE)


func _on_uniform_scale_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.SVSEditMode.SCALE)



func _on_brush_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.SVSEditMode.BRUSH)


func _on_pencil_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.SVSEditMode.PENCIL)


func _on_merge_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.SVSEditMode.MERGE)


func _on_paint_bone_toggled(toggled_on: bool) -> void:
	if toggled_on:
		mode_changed.emit(CurvedLines2D.SVSEditMode.PAINT_BONE)


func _on_flip_horizontal_pressed() -> void:
	flip_horizontal.emit()


func _on_flip_vertical_pressed() -> void:
	flip_vertical.emit()


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
		if (event as InputEventKey).keycode == KEY_M:
			%Merge.button_pressed = true
		if (event as InputEventKey).keycode == KEY_P:
			%Pencil.button_pressed = true
		if (event as InputEventKey).keycode == KEY_B:
			%Brush.button_pressed = true
