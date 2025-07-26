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


class ClipResult:
	var outlines: Array[PackedVector2Array]
	var polygons: Array[PackedVector2Array]
	func _init(ol = [], p = []):
		outlines = ol
		polygons = p


static func apply_clips_to_polygon(polygon : PackedVector2Array, clips) -> ClipResult:
	var current_polygons : Array[PackedVector2Array] = [polygon]
	var holes : Array[PackedVector2Array] = []
	var outlines : Array[PackedVector2Array] = []
	for clip_poly in clips:
		var result_polygons : Array[PackedVector2Array] = []
		for current_points : PackedVector2Array in current_polygons:
			var result = Geometry2D.clip_polygons(current_points, clip_poly)
			for poly_points in result:
				if Geometry2D.is_polygon_clockwise(poly_points):
					holes.append(poly_points)
				else:
					result_polygons.append(poly_points)
		current_polygons.clear()
		current_polygons.append_array(result_polygons)

	if not current_polygons.is_empty():
		outlines = current_polygons.duplicate()

	if not holes.is_empty():
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
	outlines.append_array(holes)
	return ClipResult.new(outlines, current_polygons)
