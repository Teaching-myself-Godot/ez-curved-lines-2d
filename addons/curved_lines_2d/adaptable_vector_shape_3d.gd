@tool
extends Node3D

class_name AdaptableVectorShape3D

const STORED_CURVE_META_NAME := "_stored_curve_data_"
const STORED_ARC_LIST_META_NAME := "_stored_arc_list_data_"
const STORED_SHAPE_TYPE_META_NAME := "_stored_shape_type_"
const STORED_SIZE_META_NAME := "_stored_shape_size_"
const STORED_RX_META_NAME := "_stored_shape_rx_"
const STORED_RY_META_NAME := "_stored_shape_ry_"
const STORED_OFFSET_META_NAME := "_stored_shape_offset_"
const STORED_STROKE_WIDTH_META_NAME := "_stored_stroke_width_"
const STORED_JOINT_MODE_META_NAME := "_stored_joint_mode_"
const STORED_LINE_CAP_META_NAME := "_stored_line_cap_"

@export var guide_svs : ScalableVectorShape2D:
	set(svs):
		if is_instance_valid(guide_svs) and guide_svs != svs:
			if guide_svs.polygons_updated.is_connected(_on_guide_svs_polygons_updated):
				guide_svs.polygons_updated.disconnect(_on_guide_svs_polygons_updated)
		guide_svs = svs
		if is_instance_valid(guide_svs):
			_on_guide_svs_assigned()


@export var fill_polygons : Array[CSGPolygon3D] = []
@export var stroke_polygons : Array[CSGPolygon3D] = []

var _update_locked := false

func _on_guide_svs_assigned():
	guide_svs.update_curve_at_runtime = true
	guide_svs.polygons_updated.connect(_on_guide_svs_polygons_updated)
	guide_svs.curve_changed()


func _on_guide_svs_polygons_updated(polygons : Array[PackedVector2Array],
			poly_strokes : Array[PackedVector2Array], _svs : ScalableVectorShape2D):

	if _update_locked:
		return
	_update_locked = true
	for p in fill_polygons + stroke_polygons:
		p.hide()

	for i in polygons.size():
		if i < fill_polygons.size():
			fill_polygons[i].show()
			fill_polygons[i].polygon = polygons[i]
		else:
			var extra_fp := fill_polygons[i - 1].duplicate()
			extra_fp.polygon = polygons[i]
			fill_polygons.append(extra_fp)
			add_child(extra_fp, true)
			extra_fp.owner = owner

	for i in poly_strokes.size():
		if i < stroke_polygons.size():
			stroke_polygons[i].show()
			stroke_polygons[i].polygon = poly_strokes[i]
		else:
			var extra_sp := stroke_polygons[i - 1].duplicate()
			extra_sp.polygon = poly_strokes[i]
			stroke_polygons.append(extra_sp)
			add_child(extra_sp, true)
			extra_sp.owner = owner
	_update_locked = false

static func is_stroke_in_front_of_fill(svs : ScalableVectorShape2D) -> bool:
	var stroke_node : Node2D = (svs.line if is_instance_valid(svs.line) else svs.poly_stroke)
	if not is_instance_valid(stroke_node):
		return false
	if not is_instance_valid(svs.polygon):
		return true
	var fill_found := false
	for ch in svs.get_children():
		if ch == svs.polygon:
			fill_found = true
		if ch == stroke_node and fill_found:
			return true

	return false


static func extract_csg_polygons_from_scalable_vector_shapes(svs : ScalableVectorShape2D,
			is_strokes := false, is_line_2d_strokes := false, z_index := 0.0) -> Array[CSGPolygon3D]:
	var result : Array[CSGPolygon3D] = []
	var polygons = (
		svs.cached_poly_strokes
			if is_strokes else
		([svs.cached_outline] if svs.clip_paths.is_empty() else svs.cached_clipped_polygons)
	)
	for poly : PackedVector2Array in polygons:
		var csg_polygon := CSGPolygon3D.new()
		csg_polygon.depth = 0.01
		csg_polygon.position.z = 0.01 * z_index
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
