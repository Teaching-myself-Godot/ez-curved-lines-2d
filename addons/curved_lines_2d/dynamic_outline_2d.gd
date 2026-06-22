@tool
extends Line2D

class_name DynamicOutline2D

@export var shapes : Array[ScalableVectorShape2D]: set = _on_shapes_assigned

var should_update := false


func _enter_tree() -> void:
	set_meta("_edit_lock_", true)
	global_position = Vector2.ZERO
	closed = true


func _on_shapes_assigned(new_shapes : Array[ScalableVectorShape2D]) -> void:
	for svs : ScalableVectorShape2D in shapes:
		if not is_instance_valid(svs):
			continue
		if svs not in shapes:
			if svs.path_changed.is_connected(_on_path_changed):
				svs.path_changed.disconnect(_on_path_changed)
			if svs.transform_changed.is_connected(_on_path_changed):
				svs.transform_changed.disconnect(_on_path_changed)
	for svs : ScalableVectorShape2D in new_shapes:
		if not is_instance_valid(svs):
			continue
		if not svs.path_changed.is_connected(_on_path_changed):
			svs.path_changed.connect(_on_path_changed)
		if not svs.transform_changed.is_connected(_on_path_changed):
			svs.set_notify_transform(true)
			svs.transform_changed.connect(_on_path_changed)

	shapes = new_shapes
	should_update = true


func _on_path_changed(_new_points = null) -> void:
	should_update = true


func _update_points() -> void:
	var shape_polygons := Array(shapes.filter(func(s): return s is ScalableVectorShape2D)
			.map(func(s : ScalableVectorShape2D): return Array(s.tessellate()).map(func(p): return s.to_global(p))
		), TYPE_PACKED_VECTOR2_ARRAY, "", null)
	if shape_polygons.is_empty():
		return
	var result := Geometry2DUtil.calculate_outlines(shape_polygons)
	if result.size() > 0:
		points = Array(result[0]).map(func(p): return to_local(p))


func _process(_delta: float) -> void:
	if not should_update:
		return
	_update_points()
	should_update = false
