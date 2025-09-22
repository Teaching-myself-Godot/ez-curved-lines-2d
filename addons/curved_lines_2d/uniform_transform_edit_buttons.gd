@tool
extends Control

signal mode_changed(mode : CurvedLines2D.UniformTransformMode)

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

