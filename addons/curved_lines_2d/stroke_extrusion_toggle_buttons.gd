@tool
extends Control

signal changed(stroke_extrusion : ScalableVectorShape2D.StrokeExtrusionDirection)

func set_toggle_to(stroke_extrusion : ScalableVectorShape2D.StrokeExtrusionDirection) -> void:
	match stroke_extrusion:
		ScalableVectorShape2D.StrokeExtrusionDirection.OUTWARD:
			%OutsideToggleButton.button_pressed = true
		ScalableVectorShape2D.StrokeExtrusionDirection.INWARD:
			%InsideToggleButton.button_pressed = true
		ScalableVectorShape2D.StrokeExtrusionDirection.MIDDLE, _:
			%MiddleToggleButton.button_pressed = true


func _on_middle_toggle_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		changed.emit(ScalableVectorShape2D.StrokeExtrusionDirection.MIDDLE)


func _on_outside_toggle_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		changed.emit(ScalableVectorShape2D.StrokeExtrusionDirection.OUTWARD)


func _on_inside_toggle_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		changed.emit(ScalableVectorShape2D.StrokeExtrusionDirection.INWARD)
