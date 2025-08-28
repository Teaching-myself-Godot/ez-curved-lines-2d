@tool
extends Node3D

class_name AdaptableVectorShape3D


@export var guide_svs : ScalableVectorShape2D:
	set(svs):
		guide_svs = svs
		guide_svs.update_curve_at_runtime = true
		guide_svs.polygons_updated.connect(_on_guide_svs_polygons_updated)
		guide_svs.curve_changed()


@export var fill_polygons : Array[CSGPolygon3D] = []
@export var stroke_polygons : Array[CSGPolygon3D] = []

func _ready() -> void:
	if not guide_svs.polygons_updated.is_connected(_on_guide_svs_polygons_updated):
		guide_svs.polygons_updated.connect(_on_guide_svs_polygons_updated)


func _on_guide_svs_polygons_updated(polygons : Array[PackedVector2Array], poly_strokes : Array[PackedVector2Array], _svs : ScalableVectorShape2D):
	for i in polygons.size():
		if i < fill_polygons.size():
			fill_polygons[i].polygon = polygons[i]

	for i in poly_strokes.size():
		if i < stroke_polygons.size():
			stroke_polygons[i].polygon = poly_strokes[i]

