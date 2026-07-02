class_name SVSPolygonCacher extends Node

@export var animation_player : AnimationPlayer: set = _on_animation_player_assigned
@export var snap_resolution := 0.01


var _caching_enabled := false
var _caching_locked := false
var _prev_animation := ""

var _outline_cache : Dictionary[String, PackedVector2Array] = {}

func _ready() -> void:
	if not get_parent() is ScalableVectorShape2D:
		push_error("SVSPolygonCacher must be a child of a ScalableVectorShape2D.")
		queue_free()
		return
	(get_parent() as ScalableVectorShape2D).cache_manager = self


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


func _mk_cache_key() -> String:
	return str(snappedf(animation_player.current_animation_position, snap_resolution)) + ":" + animation_player.current_animation


func has_outline() -> bool:
	if _caching_locked or not _caching_enabled:
		return false
	return _mk_cache_key() in _outline_cache


func get_outline() -> PackedVector2Array:
	return _outline_cache[_mk_cache_key()]


func set_outline(outline : PackedVector2Array) -> void:
	if _caching_locked or not _caching_enabled:
		return
	_outline_cache[_mk_cache_key()] = outline.duplicate()
