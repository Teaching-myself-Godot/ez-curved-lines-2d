@tool
extends Control

signal changed(cap : Line2D.LineCapMode)


func set_toggle_to(cap : Line2D.LineCapMode) -> void:
	match cap:
		Line2D.LINE_CAP_BOX:
			%BoxCapToggleButton.button_pressed = true
		Line2D.LINE_CAP_ROUND:
			%RoundCapToggleButton.button_pressed = true
		Line2D.LINE_CAP_NONE, _:
			%NoCapToggleButton.button_pressed = true


func _on_no_cap_toggle_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		changed.emit(Line2D.LINE_CAP_NONE)


func _on_box_cap_toggle_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		changed.emit(Line2D.LINE_CAP_BOX)


func _on_round_cap_toggle_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		changed.emit(Line2D.LINE_CAP_ROUND)

