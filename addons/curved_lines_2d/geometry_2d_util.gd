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
	var box := get_polygon_bounding_rect(polygon)
	if not box.has_point(slice_target):
		return [polygon]

	var intersections : Array[PackedVector2Array] = Geometry2D.intersect_polyline_with_polygon(
		[Vector2(slice_target.x, box.position.y), Vector2(slice_target.x, box.position.y + box.size.y)], polygon
	)
	if intersections.is_empty():
		return [polygon]
	var relevant_intersection_idx = intersections.find_custom(
		func(inters): return (
			(inters[0].y < slice_target.y and inters[1].y > slice_target.y) or
			(inters[0].y > slice_target.y and inters[1].y < slice_target.y)
		)
	)
	if relevant_intersection_idx == -1:
		return [polygon]

	# adaptation of knife tool:
	# https://github.com/mrkdji/knife-tool/blob/64f5838fa79192bc0c221cf36d53f8403ee0ffc5/knife_tool.gd#L299-L349
	var intersection = intersections[relevant_intersection_idx]
	var does_intersect = false
	var result : Array[PackedVector2Array] = []
	var intersection_point_a = intersection[0]
	var intersection_point_b = intersection[intersection.size() - 1]
	for extreme in [intersection_point_a, intersection_point_b]:
		for i in polygon.size():
			var next_index = posmod(i + 1, polygon.size())
			var point_on_segment = Geometry2D.get_closest_point_to_segment(
				extreme,
				polygon[i], polygon[next_index])
			# check if the cut pass through the polygon vertices
			if (polygon[i].distance_to(extreme) < THRESHOLD or
				polygon[next_index].distance_to(extreme) < THRESHOLD):
				does_intersect = true
			elif point_on_segment.distance_to(extreme) < THRESHOLD:
				does_intersect = true
				polygon.insert(next_index, point_on_segment)
				break

	var intersection_point_a_index = 0
	while polygon[intersection_point_a_index].distance_to(intersection_point_a) > THRESHOLD:
		intersection_point_a_index += 1

	for step in [1, -1]:
		var polyslice : PackedVector2Array = []
		var index = intersection_point_a_index
		while polygon[index].distance_to(intersection_point_b) > THRESHOLD:
			polyslice.append(polygon[index])
			index = posmod(index + step, polygon.size())
		polyslice.append(intersection_point_b)
		var internal_points_index = intersection.size() - 2
		while internal_points_index > 0:
			polyslice.append(intersection[internal_points_index])
			internal_points_index -= 1
		result.push_back(polyslice)
	return result


## TODO: document
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
