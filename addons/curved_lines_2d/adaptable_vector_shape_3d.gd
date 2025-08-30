@tool
extends Node3D

class_name AdaptableVectorShape3D


@export var guide_svs : ScalableVectorShape2D:
	set(svs):
		if is_instance_valid(guide_svs) and guide_svs != svs:
			for p in fill_polygons + stroke_polygons:
				p.queue_free()
			fill_polygons.clear()
			stroke_polygons.clear()
			if guide_svs.polygons_updated.is_connected(_on_guide_svs_polygons_updated):
				guide_svs.polygons_updated.disconnect(_on_guide_svs_polygons_updated)
			if guide_svs.transform_changed.is_connected(_on_guide_svs_transform_changed):
				guide_svs.transform_changed.disconnect(_on_guide_svs_transform_changed)
		guide_svs = svs
		if is_instance_valid(guide_svs):
			_on_guide_svs_assigned()


@export var fill_polygons : Array[CSGPolygon3D] = []
@export var stroke_polygons : Array[CSGPolygon3D] = []


func _on_guide_svs_assigned():
	if Engine.is_editor_hint():
		fill_polygons = extract_csg_polygons_from_scalable_vector_shapes(guide_svs)
		stroke_polygons = extract_csg_polygons_from_scalable_vector_shapes(guide_svs, true, is_instance_valid(guide_svs.line))
		for p in fill_polygons + stroke_polygons:
			add_child(p, true)
			p.owner = owner
	guide_svs.update_curve_at_runtime = true
	guide_svs.set_notify_local_transform(true)
	guide_svs.polygons_updated.connect(_on_guide_svs_polygons_updated)
	guide_svs.transform_changed.connect(_on_guide_svs_transform_changed)
	guide_svs.curve_changed()
	_on_guide_svs_transform_changed(guide_svs)


func _on_guide_svs_polygons_updated(polygons : Array[PackedVector2Array], poly_strokes : Array[PackedVector2Array], _svs : ScalableVectorShape2D):
	for p in fill_polygons + stroke_polygons:
		p.hide()
	for i in polygons.size():
		if i < fill_polygons.size():
			fill_polygons[i].show()
			fill_polygons[i].polygon = polygons[i]
	for i in poly_strokes.size():
		if i < stroke_polygons.size():
			stroke_polygons[i].show()
			stroke_polygons[i].polygon = poly_strokes[i]


func _on_guide_svs_transform_changed(_svs : ScalableVectorShape2D):
	var stored_z := position.z
	transform = guide_svs.transform
	position.z = stored_z


static func extract_csg_polygons_from_scalable_vector_shapes(svs : ScalableVectorShape2D,
			is_strokes := false, is_line_2d_strokes := false) -> Array[CSGPolygon3D]:
	var result : Array[CSGPolygon3D] = []
	var polygons = (
		svs.cached_poly_strokes
			if is_strokes else
		([svs.cached_outline] if svs.clip_paths.is_empty() else svs.cached_clipped_polygons)
	)
	for poly : PackedVector2Array in polygons:
		var csg_polygon := CSGPolygon3D.new()
		csg_polygon.depth = 0.01
		csg_polygon.polygon = poly
		csg_polygon.material = StandardMaterial3D.new()
		csg_polygon.material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		csg_polygon.material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		if is_strokes:
			csg_polygon.material.albedo_color = svs.stroke_color
			if is_line_2d_strokes:
				csg_polygon.name = svs.line.name
			else:
				csg_polygon.name = svs.poly_stroke.name
				csg_polygon.material.albedo_texture = svs.poly_stroke.texture
		else:
			csg_polygon.name = svs.polygon.name
			csg_polygon.material.albedo_color = svs.polygon.color
			csg_polygon.material.albedo_texture = svs.polygon.texture
		result.append(csg_polygon)
	return result
