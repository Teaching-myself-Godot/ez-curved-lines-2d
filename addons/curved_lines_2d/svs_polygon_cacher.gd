class_name SVSPolygonCacher extends Node

@export var animation_player : AnimationPlayer
@export var cache : SVSPolygonCacheResource

var _is_recording := false
var _frame_count := 0
var _prev_animation := ""

func start_recording() -> void:
	_is_recording = true
	_prev_animation = animation_player.current_animation
	_frame_count = 0


func end_recording() -> void:
	_is_recording = false
	_frame_count = 0


func _process(_delta: float) -> void:
	if not _is_recording:
		return
	if is_instance_valid(animation_player):
		if _prev_animation != animation_player.current_animation:
			end_recording()
			return
		_prev_animation = animation_player.current_animation
		_frame_count += 1
