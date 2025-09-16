extends Node2D


func _ready() -> void:
	$AnimationPlayer.play("dance")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				%RightEye.is_open = false
			else:
				%LeftEye.is_open = false
		else:
			if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				%RightEye.is_open = true
			else:
				%LeftEye.is_open = true
