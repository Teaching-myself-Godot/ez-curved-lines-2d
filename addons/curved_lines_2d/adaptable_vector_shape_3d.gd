@tool
extends Node3D

class_name AdaptableVectorShape3D


@export var guide_svs : ScalableVectorShape2D:
	set(svs):
		if is_instance_valid(guide_svs) and guide_svs != svs:
			if guide_svs.polygons_updated.is_connected(_on_guide_svs_polygons_updated):
				guide_svs.polygons_updated.disconnect(_on_guide_svs_polygons_updated)
			if guide_svs.transform_changed.is_connected(_on_guide_svs_transform_changed):
				guide_svs.transform_changed.disconnect(_on_guide_svs_transform_changed)
		guide_svs = svs
		if is_instance_valid(guide_svs):
			guide_svs.update_curve_at_runtime = true
			guide_svs.set_notify_local_transform(true)
			guide_svs.polygons_updated.connect(_on_guide_svs_polygons_updated)
			guide_svs.transform_changed.connect(_on_guide_svs_transform_changed)
			guide_svs.curve_changed()


@export var fill_polygons : Array[CSGPolygon3D] = []
@export var stroke_polygons : Array[CSGPolygon3D] = []

func _on_guide_svs_polygons_updated(polygons : Array[PackedVector2Array], poly_strokes : Array[PackedVector2Array], _svs : ScalableVectorShape2D):
	for i in polygons.size():
		if i < fill_polygons.size():
			fill_polygons[i].polygon = polygons[i]

	for i in poly_strokes.size():
		if i < stroke_polygons.size():
			stroke_polygons[i].polygon = poly_strokes[i]


func _on_guide_svs_transform_changed(_svs : ScalableVectorShape2D):
	var stored_z := position.z
	transform = guide_svs.transform
	position.z = stored_z
