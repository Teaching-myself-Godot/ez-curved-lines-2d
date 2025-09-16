@tool
extends Object
class_name Geometry2DUtil

const THRESHOLD = 0.1

static func get_polygon_bounding_rect(points : PackedVector2Array) -> Rect2:
	var minx := INF
	var miny := INF
	var maxx := -INF
	var maxy := -INF
	for p : Vector2 in points:
		minx = p.x if p.x < minx else minx
		miny = p.y if p.y < miny else miny
		maxx = p.x if p.x > maxx else maxx
		maxy = p.y if p.y > maxy else maxy
	return Rect2(minx, miny, maxx - minx, maxy - miny)


static func get_polygon_center(points : PackedVector2Array) -> Vector2:
	return get_polygon_bounding_rect(points).get_center()


static func slice_polygon_vertical(polygon : PackedVector2Array, slice_target : Vector2) -> Array[PackedVector2Array]:
	var box := get_polygon_bounding_rect(polygon).grow(1.0)
	if not box.has_point(slice_target):
		return [polygon]
	return Geometry2D.intersect_polygons([
		box.position,
		Vector2(slice_target.x, box.position.y),
		Vector2(slice_target.x, box.position.y + box.size.y),
		Vector2(box.position.x, box.position.y + box.size.y),
	], polygon) + Geometry2D.intersect_polygons([
		Vector2(slice_target.x, box.position.y),
		Vector2(box.position.x + box.size.x, box.position.y),
		box.position + box.size,
		Vector2(slice_target.x, box.position.y + box.size.y),
	], polygon)


static func apply_polygon_bool_operation_in_place(
		current_polygons : Array[PackedVector2Array],
		other_polygons : Array[PackedVector2Array],
		operation : Geometry2D.PolyBooleanOperation) -> Array[PackedVector2Array]:
	var holes : Array[PackedVector2Array] = []
	for other_poly in other_polygons:
		var result_polygons : Array[PackedVector2Array] = []
		for current_points : PackedVector2Array in current_polygons:
			if other_poly == current_points:
				continue
			var result = (
					Geometry2D.merge_polygons(current_points, other_poly)
						if operation == Geometry2D.PolyBooleanOperation.OPERATION_UNION else
					Geometry2D.intersect_polygons(current_points, other_poly)
						if operation == Geometry2D.PolyBooleanOperation.OPERATION_INTERSECTION else
					Geometry2D.clip_polygons(current_points, other_poly)
			)
			for poly_points in result:
				if Geometry2D.is_polygon_clockwise(poly_points):
					holes.append(poly_points)
				else:
					result_polygons.append(poly_points)
		current_polygons.clear()
		current_polygons.append_array(result_polygons)
	return holes

## TODO: document
static func apply_clips_to_polygon(
			current_polygons : Array[PackedVector2Array],
			clips : Array[PackedVector2Array],
			operation : Geometry2D.PolyBooleanOperation) -> Array[PackedVector2Array]:
	var holes := apply_polygon_bool_operation_in_place(
		current_polygons, clips, operation
	)
	if not holes.is_empty():
		slice_polygons_with_holes(current_polygons, holes)
	return current_polygons


static func slice_polygons_with_holes(current_polygons : Array[PackedVector2Array], holes : Array[PackedVector2Array]) -> void:
	var result_polygons : Array[PackedVector2Array] = []
	for hole in holes:
		for current_points : PackedVector2Array in current_polygons:
			var slices := slice_polygon_vertical(
				current_points, get_polygon_center(hole)
			)
			for slice in slices:
				var result = Geometry2D.clip_polygons(slice, hole)
				for poly_points in result:
					if not Geometry2D.is_polygon_clockwise(poly_points):
						result_polygons.append(poly_points)
		current_polygons.clear()
		current_polygons.append_array(result_polygons)
		result_polygons.clear()



static func calculate_outlines(result : Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	if result.size() <= 1:
		return result
	var succesful_merges := true
	var guard = 0
	var holes : Array[PackedVector2Array] = []
	while succesful_merges and result.size() > 1 and guard < 1000:
		succesful_merges = false
		guard += 1
		var indices_to_be_removed : Dictionary[int, bool] = {}
		var merged_to_be_appended : Array[PackedVector2Array] = []

		for current_poly_idx in result.size():
			if current_poly_idx in indices_to_be_removed:
				continue
			for other_poly_idx in result.size():
				if current_poly_idx == other_poly_idx or other_poly_idx in indices_to_be_removed:
					continue
				var merge_result := Geometry2D.merge_polygons(
						result[current_poly_idx], result[other_poly_idx])
				var regular := merge_result.filter(func(x): return not Geometry2D.is_polygon_clockwise(x))
				var clockwise := merge_result.filter(Geometry2D.is_polygon_clockwise)
				if regular.size() == 1:
					succesful_merges = true
					indices_to_be_removed[current_poly_idx] = true
					indices_to_be_removed[other_poly_idx] = true
					merged_to_be_appended.append(regular[0])
					holes.append_array(clockwise)
		var sorted_indices = indices_to_be_removed.keys()
		sorted_indices.sort()
		sorted_indices.reverse()
		for idx in sorted_indices:
			result.remove_at(idx)
		result.append_array(merged_to_be_appended)
	return result + holes


static func calculate_polystroke(outline : PackedVector2Array, stroke_width : float,
			end_mode : Geometry2D.PolyEndType, joint_mode : Geometry2D.PolyJoinType) -> Array[PackedVector2Array]:
	if outline.is_empty():
		return []
	var poly_strokes := Geometry2D.offset_polyline(outline, stroke_width, joint_mode, end_mode)
	var result_poly_strokes := Array(poly_strokes.filter(func(ps): return not Geometry2D.is_polygon_clockwise(ps)), TYPE_PACKED_VECTOR2_ARRAY, "", null)
	var result_poly_holes := Array(poly_strokes.filter(Geometry2D.is_polygon_clockwise), TYPE_PACKED_VECTOR2_ARRAY, "", null)
	if not result_poly_holes.is_empty():
		slice_polygons_with_holes(result_poly_strokes, result_poly_holes)
	return result_poly_strokes


static func get_polygon_indices(polygons : Array[PackedVector2Array], indices : Array) -> PackedVector2Array:
	var result : PackedVector2Array = []
	var p_count = 0
	indices.clear()
	for poly_points in polygons:
		var p_range := range(p_count, poly_points.size() + p_count)
		result.append_array(poly_points)
		indices.append(p_range)
		p_count += poly_points.size()
	return result


