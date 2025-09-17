@tool
extends Control

signal changed(joint_mode : Line2D.LineJointMode)


func set_toggle_to(joint_mode : Line2D.LineJointMode) -> void:
	match joint_mode:
		Line2D.LINE_JOINT_BEVEL:
			%LineJointBevelToggleButton.button_pressed = true
		Line2D.LINE_JOINT_ROUND:
			%LineJointRoundToggleButton.button_pressed = true
		Line2D.LINE_JOINT_SHARP, _:
			%LineJointSharpToggleButton.button_pressed = true


func _on_line_joint_sharp_toggle_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		changed.emit(Line2D.LINE_JOINT_SHARP)


func _on_line_joint_round_toggle_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		changed.emit(Line2D.LINE_JOINT_ROUND)

func _on_line_joint_bevel_toggle_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		changed.emit(Line2D.LINE_JOINT_BEVEL)
