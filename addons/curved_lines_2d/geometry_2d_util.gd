@tool
extends Object
class_name Geometry2DUtil

const THRESHOLD = 0.1

## The surface below which an area enclosed by [method union_polygons] is discarded as
## rounding noise in stead of treated as a hole. When two of the polygons describe the
## same edge through a different chain of floating point operations - a stroke extruded
## up against the contour of its fill, for instance - subtracting one from the other
## leaves slivers behind, which are not holes: slicing the result around them would
## only fragment it. Measured slivers stay below 0.00001, a cutout of 1 pixel across
## still covers ~3.
const MINIMUM_HOLE_AREA = 0.1

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


## Returns the surface covered by [param points], regardless of its winding order
static func get_polygon_area(points : PackedVector2Array) -> float:
	var double_area := 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		double_area += p.x * q.y - q.x * p.y
	return absf(double_area) * 0.5


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



## Returns the smallest set of non-overlapping polygons covering exactly the same
## area as the union of [param polygons], so a set of overlapping polygons can be
## turned into a single shape (i.e. one [CollisionPolygon2D] in stead of one per
## polygon).
## Areas enclosed by the union - holes cut out by a boolean operation, or an area
## trapped between two of the polygons - are preserved by slicing the result around
## them, because [CollisionPolygon2D] and [Polygon2D] cannot represent a hole.
static func union_polygons(polygons : Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var sources : Array[PackedVector2Array] = []
	for poly in polygons:
		if poly.size() > 2:
			sources.append(poly)
	if sources.size() < 2:
		return sources

	var solids := sources.duplicate()
	if not _merge_until_stable(solids):
		# no merge ever enclosed an area, so the union cannot contain a hole
		return solids

	# a merge only reports the outline of the _pair_ it merged, so an area it enclosed
	# may have been filled up by another polygon of the set: what is really left
	# uncovered within the merged outlines are the holes
	var holes : Array[PackedVector2Array] = []
	for solid in solids:
		for hole in _subtract_polygons(solid, sources):
			if get_polygon_area(hole) > MINIMUM_HOLE_AREA:
				holes.append(hole)
	if not holes.is_empty():
		slice_polygons_with_holes(solids, holes)
	return solids


# Merges every pair of overlapping polygons in [param solids] - in place - until no
# pair can be merged anymore. Returns whether any merge enclosed an area, which is
# the only way the resulting union can end up with a hole in it.
static func _merge_until_stable(solids : Array[PackedVector2Array]) -> bool:
	var enclosed_area := false
	var merged := true
	var guard := 0
	while merged and solids.size() > 1 and guard < 1000:
		merged = false
		guard += 1
		var merged_indices : Dictionary[int, bool] = {}
		var merge_results : Array[PackedVector2Array] = []
		for current_idx in solids.size():
			if current_idx in merged_indices:
				continue
			for other_idx in range(current_idx + 1, solids.size()):
				if other_idx in merged_indices:
					continue
				var result := Geometry2D.merge_polygons(solids[current_idx], solids[other_idx])
				var outlines := result.filter(func(p): return not Geometry2D.is_polygon_clockwise(p))
				if outlines.size() != 1:
					# the two polygons are disjoint: merging them changed nothing
					continue
				merged = true
				enclosed_area = enclosed_area or outlines.size() < result.size()
				merged_indices[current_idx] = true
				merged_indices[other_idx] = true
				merge_results.append(outlines[0])
				# solids[current_idx] is stale now, so continue with the next one
				break
		var sorted_indices := merged_indices.keys()
		sorted_indices.sort()
		sorted_indices.reverse()
		for idx in sorted_indices:
			solids.remove_at(idx)
		solids.append_array(merge_results)
	return enclosed_area


# Subtracts every polygon in [param subtrahends] from [param minuend] and returns the
# parts of it which none of them covers.
# A subtrahend lying completely inside the remainder is postponed: subtracting it
# would turn the remainder into a polygon _with_ a hole, which then has to be sliced
# up into several polygons. Subtracting the overlapping ones first usually shrinks the
# remainder far enough for the postponed ones to overlap it as well, so it can stay in
# one piece. What is still enclosed once nothing else is left really is an island.
static func _subtract_polygons(minuend : PackedVector2Array,
			subtrahends : Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var remainder : Array[PackedVector2Array] = [minuend]
	var todo := subtrahends.duplicate()
	while not todo.is_empty() and not remainder.is_empty():
		var postponed : Array[PackedVector2Array] = []
		for subtrahend in todo:
			var difference : Array[PackedVector2Array] = []
			var is_enclosed := false
			for part in remainder:
				for piece in Geometry2D.clip_polygons(part, subtrahend):
					if Geometry2D.is_polygon_clockwise(piece):
						is_enclosed = true
					else:
						difference.append(piece)
			if is_enclosed:
				postponed.append(subtrahend)
			else:
				remainder = difference
		if postponed.size() == todo.size():
			# only enclosed polygons are left: slice the remainder around them, in
			# stead of leaving it with a hole it cannot represent
			slice_polygons_with_holes(remainder, postponed)
			return remainder
		todo = postponed
	return remainder


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
			end_mode : Geometry2D.PolyEndType, joint_mode : Geometry2D.PolyJoinType,
			offset_poly : float) -> Array[PackedVector2Array]:
	if outline.is_empty():
		return []
	var offset_result := Geometry2D.offset_polygon(outline, offset_poly, joint_mode) if not is_zero_approx(offset_poly) else ([] as Array[PackedVector2Array])
	var offsetted_outline := outline if offset_result.is_empty() else offset_result[0]
	var poly_strokes := Geometry2D.offset_polyline(offsetted_outline, stroke_width, joint_mode, end_mode)
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


static func is_point_on_segment(p : Vector2, s1 : Vector2, s2: Vector2) -> bool:
	return Geometry2D.segment_intersects_circle(s1, s2, p, 0.01) > -1


static func get_rotation_of_polyline_segment_at_point(p : Vector2, poly_points : PackedVector2Array) -> float:
	var closest_result := Vector2.INF
	var segment_idx := 0
	for i in range(1, poly_points.size()):
		var p_a := poly_points[i - 1]
		var p_b := poly_points[i]
		var c_p := Geometry2D.get_closest_point_to_segment(p, p_a, p_b)

		if p.distance_to(c_p) < p.distance_to(closest_result):
			closest_result = c_p
			segment_idx = i - 1
	return poly_points[segment_idx].angle_to_point(poly_points[segment_idx + 1])


static func get_closest_point_on_polyline(p : Vector2, poly_points : PackedVector2Array) -> Vector2:
	var closest_result := Vector2.INF
	for i in range(1, poly_points.size()):
		var p_a := poly_points[i - 1]
		var p_b := poly_points[i]
		var c_p := Geometry2D.get_closest_point_to_segment(p, p_a, p_b)
		if p.distance_to(c_p) < p.distance_to(closest_result):
			closest_result = c_p
	return closest_result


static func get_intersection_point_on_polyline(p1 : Vector2, q1 : Vector2, poly_points : PackedVector2Array) -> Vector2:
	var closest_distance := INF
	var closest_result := Vector2.INF
	for i in range(1, poly_points.size()):
		var p2 := poly_points[i - 1]
		var q2 := poly_points[i]
		var result := Geometry2D.get_closest_points_between_segments(p1, q1, p2, q2)
		var distance := p1.distance_to(result[1])
		if result[0].is_equal_approx(result[1]) and distance < closest_distance:
			closest_result = result[1]
			closest_distance = distance
	return closest_result



static func get_progress_ratio_for_point_on_curve(p : Vector2, c : Curve2D, max_stages := 5,
		tolerance_degrees := 4.0) -> float:
	# Heuristic to find progress_ratio of cpc
	var d := 0.0
	var pts := c.tessellate(max_stages, tolerance_degrees)
	var p1 := pts[0]
	for i in range(1, pts.size()):
		if Geometry2DUtil.is_point_on_segment(p, p1, pts[i]):
			d += p1.distance_to(p)
			break
		d += p1.distance_to(pts[i])
		p1 = pts[i]
	return d / c.get_baked_length()


static func get_halfway_point_on_bezier(c : Curve2D, max_stages := 5, tolerance_degrees := 4.0) -> Vector2:
	return get_point_on_bezier_at_ratio(c, 0.5, max_stages, tolerance_degrees)


static func get_point_on_bezier_at_ratio(c : Curve2D, ratio : float, max_stages := 5, tolerance_degrees := 4.0) -> Vector2:
	var pts := c.tessellate(max_stages, tolerance_degrees)
	var tot_d := c.get_baked_length()
	return get_point_on_polyline_at_ratio(pts, ratio, tot_d)


static func get_polyline_length(pts : PackedVector2Array) -> float:
	var d := 0.0
	for i in range(1, pts.size()):
		d += pts[i-1].distance_to(pts[i])
	return d


static func get_point_on_polyline_at_ratio(pts : PackedVector2Array, ratio : float, tot_d : float) -> Vector2:
	var d := 0.0
	var p1 := pts[0]
	for i in range(1, pts.size()):
		var prev_d := d
		d += p1.distance_to(pts[i])
		if d >= tot_d * ratio or is_equal_approx(d, tot_d):
			var d_ratio := ratio - (prev_d / tot_d) if prev_d > 0.0 else ratio
			var d_abs := tot_d * d_ratio
			return pts[i-1] + pts[i-1].direction_to(pts[i]) * d_abs
		p1 = pts[i]
	return pts[-1]


static func get_polygon_at_granularity(poly : PackedVector2Array, granularity : float) -> PackedVector2Array:
	var def_poly := PackedVector2Array()
	def_poly.append(poly[0])
	for i in range(1, poly.size()):
		if poly[i].distance_to(def_poly[-1]) > granularity:
			def_poly.append(poly[i])
	return def_poly


# Adapted from: https://stackoverflow.com/a/8405756/1081548
static func slice_bezier(p1: Vector2, cp2 : Vector2, cp3 : Vector2, p4 : Vector2, t : float) -> Curve2D:
	var x1 := p1.x
	var y1 := p1.y
	var x2 := x1 + cp2.x
	var y2 := y1 + cp2.y
	var x4 := p4.x
	var y4 := p4.y
	var x3 := x4 + cp3.x
	var y3 := y4 + cp3.y
	var x12 := (x2-x1)*t+x1
	var y12 = (y2-y1)*t+y1
	var x23 = (x3-x2)*t+x2
	var y23 = (y3-y2)*t+y2
	var x34 = (x4-x3)*t+x3
	var y34 = (y4-y3)*t+y3
	var x123 = (x23-x12)*t+x12
	var y123 = (y23-y12)*t+y12
	var x234 = (x34-x23)*t+x23
	var y234 = (y34-y23)*t+y23
	var x1234 = (x234-x123)*t+x123
	var y1234 = (y234-y123)*t+y123
	var sliced_curve := Curve2D.new()
	sliced_curve.add_point(Vector2(x1, y1))
	sliced_curve.add_point(Vector2(x1234, y1234))
	sliced_curve.add_point(Vector2(x4, y4))
	sliced_curve.set_point_out(0, Vector2(x12, y12) - sliced_curve.get_point_position(0))
	sliced_curve.set_point_in(1, Vector2(x123, y123) - sliced_curve.get_point_position(1))
	sliced_curve.set_point_out(1, Vector2(x234, y234) - sliced_curve.get_point_position(1))
	sliced_curve.set_point_in(2, Vector2(x34, y34) - sliced_curve.get_point_position(2))
	return sliced_curve

