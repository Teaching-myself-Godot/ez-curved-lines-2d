@tool
extends Node2D

class_name SVSVertexMerge2D

@export var vertex_map : Dictionary[ScalableVectorShape2D, int] = {}:
	set = _set_vertex_owners


var _update_locked := false


func _enter_tree() -> void:
	set_notify_local_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		if vertex_map.size() > 1:
			var svs : ScalableVectorShape2D = vertex_map.keys()[0]
			svs.curve.set_point_position(vertex_map[svs], svs.to_local(global_position))


func _set_vertex_owners(new_lst : Dictionary[ScalableVectorShape2D, int]):
	for svs : ScalableVectorShape2D in vertex_map.keys().filter(is_instance_valid):
		if svs.polygons_updated.is_connected(_on_svs_curve_changed):
			svs.polygons_updated.disconnect(_on_svs_curve_changed)
		if svs.transform_changed.is_connected(_on_svs_transform_changed):
			svs.transform_changed.disconnect(_on_svs_transform_changed)
	vertex_map = new_lst
	for svs : ScalableVectorShape2D  in vertex_map.keys().filter(is_instance_valid):
		if not svs.polygons_updated.is_connected(_on_svs_curve_changed):
			svs.polygons_updated.connect(_on_svs_curve_changed)
		if not svs.transform_changed.is_connected(_on_svs_transform_changed):
			svs.set_notify_local_transform(true)
			svs.transform_changed.connect(_on_svs_transform_changed)


func _on_svs_transform_changed(svs : ScalableVectorShape2D):
	_align_vertices(svs)


func _on_svs_curve_changed(
		_a : Array[PackedVector2Array],
		_b : Array[PackedVector2Array],
		svs : ScalableVectorShape2D):
	_align_vertices(svs)


func _align_vertices(svs : ScalableVectorShape2D):
	var global_vertex_pos := svs.to_global(svs.curve.get_point_position(vertex_map[svs]))
	global_position = global_vertex_pos
	for svs1 : ScalableVectorShape2D in vertex_map.keys().filter(is_instance_valid):
		if svs1 != svs:
			var new_pos := svs1.to_local(global_vertex_pos)
			var old_pos := svs1.curve.get_point_position(vertex_map[svs1])
			if not old_pos.is_equal_approx(new_pos):
				var idx := vertex_map[svs1]
				var is_closed := svs1.is_curve_closed()
				if is_closed:
					if idx == 0:
						svs1.curve.set_point_position(svs1.curve.point_count - 1, new_pos)
					elif idx == svs1.curve.point_count - 1:
						svs1.curve.set_point_position(0, new_pos)
				svs1.curve.set_point_position(idx, new_pos)
