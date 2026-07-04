class_name SVSPolygonCacher extends Node

@export var animation_player : AnimationPlayer: set = _on_animation_player_assigned
@export var is_recording := false:
	set(new_val):
		is_recording = new_val
		_cache_locks = 0


@export var snap_resolution := 0.01:
	set(new_snap):
		snap_resolution = new_snap
		is_recording = false
		_outline_cache.clear()


var _cache_locks : int = 0
var _prev_animation := ""
var _have_warned := false
var _outline_cache : Dictionary[String, PackedVector2Array] = {}
var cache_hits := 0
var cache_misses := 0

func _ready() -> void:
	if not 'svs_cache_manager' in get_parent():
		push_error("SVSPolygonCacher must be assignable to its parent `svs_cache_manager`.")
		queue_free()
		return
	get_parent().svs_cache_manager = self


func _on_animation_player_assigned(a : AnimationPlayer) -> void:
	if is_instance_valid(animation_player) and animation_player.current_animation_changed.is_connected(_on_animation_changed):
		animation_player.current_animation_changed.disconnect(_on_animation_changed)
	animation_player = a
	if is_instance_valid(animation_player) and not animation_player.current_animation_changed.is_connected(_on_animation_changed):
		animation_player.current_animation_changed.connect(_on_animation_changed)


func _on_animation_changed(new_name : String) -> void:
	if animation_player.get_blend_time(_prev_animation, new_name) > 0.0:
		if is_recording and not _have_warned:
			push_warning("Caching is unstable when using transitions between animations")
			_have_warned = true
	_cache_locks += 1
	get_tree().create_timer(animation_player.get_blend_time(_prev_animation, new_name) * 2).timeout.connect(_on_cache_lock_timer_timeout)
	_prev_animation = new_name


func _on_cache_lock_timer_timeout() -> void:
	_cache_locks -= 1


func _mk_cache_key() -> String:
	if not is_instance_valid(animation_player):
		push_error("No AnimationPlayer assigned to SVSPolygonCacher: ", self)
		queue_free()
		return ""
	return str(snappedf(animation_player.current_animation_position, snap_resolution)) + ":" + animation_player.current_animation


func has_outline() -> bool:
	if _cache_locks > 0:
		return false
	var k := _mk_cache_key()
	if k in _outline_cache:
		if is_recording:
			cache_hits += 1
		return true
	else:
		if is_recording:
			cache_misses += 1
		return false


func get_outline() -> PackedVector2Array:
	return _outline_cache[_mk_cache_key()]


func set_outline(outline : PackedVector2Array) -> void:
	if not is_recording:
		return
	if _cache_locks > 0:
		return
	_outline_cache[_mk_cache_key()] = outline.duplicate()
