@tool
extends Node
class_name SVSPolygonCacher

@export var animation_player : AnimationPlayer: set = _on_animation_player_assigned

var _caching_enabled := false
var _caching_locked := false
var _frame_count := 0
var _prev_animation := ""

func _on_animation_player_assigned(a : AnimationPlayer) -> void:
	if is_instance_valid(animation_player) and animation_player.current_animation_changed.is_connected(_on_animation_changed):
		animation_player.current_animation_changed.disconnect(_on_animation_changed)
	animation_player = a
	if is_instance_valid(animation_player) and not animation_player.current_animation_changed.is_connected(_on_animation_changed):
		animation_player.current_animation_changed.connect(_on_animation_changed)


func _on_animation_changed(new_name : String) -> void:
	_caching_enabled = false
	if animation_player.get_blend_time(_prev_animation, new_name) > 0.0:
		_caching_locked = true
		get_tree().create_timer(animation_player.get_blend_time(_prev_animation, new_name)).timeout.connect(func(): _caching_locked = false)
	_prev_animation = new_name


func set_caching_enabled() -> void:
	_caching_enabled = true
	_frame_count = 0


func _process(delta: float) -> void:
	if not _caching_enabled:
		return
	if _caching_locked:
		return
	_frame_count += 1
	print("caching active: ", animation_player.current_animation)
