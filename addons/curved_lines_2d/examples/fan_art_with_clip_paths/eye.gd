extends Node2D

@export var is_open := true:
	set(flag):
		if flag != is_open:
			if flag:
				$AnimationPlayer.play("open")
			else:
				$AnimationPlayer.play("close")
		is_open = flag

@onready var _initial_iris_position : Vector2 = $Outline/Iris.position

func _ready() -> void:
	$AnimationPlayer.play("RESET")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		$Outline/Iris.position = _initial_iris_position + (
			position.direction_to(get_local_mouse_position()) * 1.5
		)
