@tool
extends Object
class_name Geometry2DUtil

const THRESHOLD = 0.1
const MINIMUM_HOLE_AREA = 0.1
const MINIMUM_COLLISION_AREA := 0.1

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


## Removes every vertex coinciding with the one before it, the closing vertex included.
## The boolean operations of [Geometry2D] hand back contours in which the same point
## occurs twice in a row - a corner where two clipped edges meet, most often. That is
## the same shape geometrically, but Godot cannot triangulate it: a [CollisionPolygon2D]
## carrying such a contour makes `decompose_polygon_in_convex()` bail out with
## `Convex decomposing failed!` every time the scene loads and every time the shape is
## recomputed, even when the node is hidden and disabled.
static func remove_duplicate_points(points : PackedVector2Array) -> PackedVector2Array:
	var result : PackedVector2Array = []
	for p : Vector2 in points:
		if result.is_empty() or not result[-1].is_equal_approx(p):
			result.append(p)
	while result.size() > 1 and result[0].is_equal_approx(result[-1]):
		result.remove_at(result.size() - 1)
	return result


## Returns the simple polygon(s) covering the surface enclosed by [param points].
## A contour that crosses itself - a shape dragged through itself, a clip path folded
## over its own outline - cannot be triangulated, so neither [Polygon2D] nor
## [CollisionPolygon2D] can digest it: the editor logs
## `Invalid polygon data, triangulation failed.` on every redraw and the collider
## `Convex decomposing failed!` on every rebuild, for as long as the contour stays.
## Merging such a contour with itself resolves the crossings into one simple outline
## per enclosed lobe. A contour that is already simple comes back alone, deduplicated;
## one enclosing no surface at all comes back as nothing.
static func normalize_contour(points : PackedVector2Array) -> Array[PackedVector2Array]:
	var cleaned := remove_duplicate_points(points)
	if cleaned.size() < 3:
		return []
	if not Geometry2D.triangulate_polygon(cleaned).is_empty():
		return [cleaned]
	var pieces : Array[PackedVector2Array] = []
	for piece in Geometry2D.merge_polygons(cleaned, cleaned):
		if Geometry2D.is_polygon_clockwise(piece):
			continue
		# the merge can hand a weakly simple contour straight back - lobes pinched
		# together at a repeated vertex - which not even ear clipping digests reliably
		for loop in split_at_pinch_points(remove_duplicate_points(piece)):
			if loop.size() > 2 and not Geometry2D.triangulate_polygon(loop).is_empty():
				pieces.append(loop)
	# what is left after this are sub-pixel artefacts of the merge itself - Clipper
	# works on scaled integers and can return a micro-crossing unchanged - and nothing
	# that draws or collides can digest those: they are dropped, not handed on
	return pieces


## Whether no two non-adjacent edges of the contour touch: no crossings, and no vertex
## resting on a foreign edge. Ear clipping tolerates a surprising amount of both, so a
## contour can triangulate and still be rejected by the convex partitioner that builds
## a [CollisionPolygon2D]'s shapes - which prints `Convex decomposing failed!` when it
## gives up. This is the silent test for what that partitioner will accept.
static func is_strictly_simple(points : PackedVector2Array, tolerance := 0.001) -> bool:
	var n := points.size()
	for i in n:
		var a1 := points[i]
		var a2 := points[(i + 1) % n]
		for j in range(i + 1, n):
			if j == i + 1 or (i == 0 and j == n - 1):
				continue
			var b1 := points[j]
			var b2 := points[(j + 1) % n]
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				return false
			if Geometry2D.get_closest_point_to_segment(b1, a1, a2).distance_to(b1) < tolerance:
				return false
			if Geometry2D.get_closest_point_to_segment(a1, b1, b2).distance_to(a1) < tolerance:
				return false
	return true


## Removes every vertex lying sub-pixel close to the straight edge between its two
## neighbours. The vertical cut of [method slice_polygons_with_holes] leaves such
## vertices along both halves of the cut edge and re-merging keeps them: harmless to
## the shape itself, but the convex partition of a [CollisionPolygon2D] can emit a
## zero-area piece at one - which decomposes without complaint and then fails to draw,
## logging `Invalid polygon data, triangulation failed.` on every editor redraw with
## no failing decomposition in sight.
static func remove_collinear_points(points : PackedVector2Array, tolerance := 0.01) -> PackedVector2Array:
	if points.size() < 4:
		return points
	var result : PackedVector2Array = []
	for i in points.size():
		var previous := points[(i - 1 + points.size()) % points.size()]
		var next := points[(i + 1) % points.size()]
		var on_edge := Geometry2D.get_closest_point_to_segment(points[i], previous, next)
		if on_edge.distance_to(points[i]) >= tolerance:
			result.append(points[i])
	return result if result.size() > 2 else points


## Splits a contour that touches itself at a repeated - but not consecutive - vertex
## into the separate loops meeting there, recursively. Clipper hands back such "weakly
## simple" contours whenever a union pinches two lobes together at a point: the
## ear-clipping triangulator accepts them, but the convex partitioner that builds a
## [CollisionPolygon2D]'s shapes does not, and reports `Convex decomposing failed!` on
## every physics rebuild. Each loop keeps one copy of the shared vertex, so together
## they cover exactly the surface of the original.
static func split_at_pinch_points(points : PackedVector2Array) -> Array[PackedVector2Array]:
	for i in points.size():
		for j in range(i + 1, points.size()):
			if points[i].is_equal_approx(points[j]):
				var inner := points.slice(i, j)
				var outer := points.slice(j) + points.slice(0, i)
				return split_at_pinch_points(inner) + split_at_pinch_points(outer)
	return [points]


## [method normalize_contour] applied to a whole set: the pieces of every contour, flat.
static func normalize_contours(polygons : Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result : Array[PackedVector2Array] = []
	for points in polygons:
		result.append_array(normalize_contour(points))
	return result


## The contour of [param polygons] covering the largest surface; empty when none does.
static func largest_contour(polygons : Array[PackedVector2Array]) -> PackedVector2Array:
	var best : PackedVector2Array = []
	var best_area := 0.0
	for points in polygons:
		var area := get_polygon_area(points)
		if area > best_area:
			best_area = area
			best = points
	return best


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




# Not every contour is worth a CollisionPolygon2D as it arrives:
#  - one with a vertex repeating the one before it cannot be decomposed into convex
#    shapes, which Godot reports as `Convex decomposing failed!` on load;
#  - one that crosses itself cannot either, and the editor cannot triangulate it to
#    draw it, adding `Invalid polygon data, triangulation failed.` on every redraw -
#    it is resolved into its simple pieces in stead (see normalize_contour);
#  - one that touches itself at a repeated vertex - a union pinching two lobes
#    together - triangulates but does not decompose either, and is split into the
#    separate loops meeting there (see split_at_pinch_points);
#  - one enclosing next to no surface collides with nothing and is dropped.
static func get_collidable_contours(contours : Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var usable : Array[PackedVector2Array] = []
	for contour in contours:
		for piece in Geometry2DUtil.normalize_contour(contour):
			for raw_loop in Geometry2DUtil.split_at_pinch_points(piece):
				# the slice line leaves collinear vertices along the cut: the convex
				# partition emits a zero-area piece at each, which the editor then
				# fails to draw - see remove_collinear_points
				var loop := Geometry2DUtil.remove_collinear_points(raw_loop)
				if Geometry2DUtil.get_polygon_area(loop) <= MINIMUM_COLLISION_AREA:
					continue
				if Geometry2D.triangulate_polygon(loop).is_empty():
					# still not drawable after normalization: a sub-pixel artefact
					continue
				if not Geometry2DUtil.is_strictly_simple(loop):
					# ear clipping tolerated its crossings, the convex partitioner
					# will not: resolve them silently in stead of letting the
					# partitioner print - once more through Clipper, then give up
					_append_resolved_collidable_loops(loop, usable)
					continue
				if not _decomposes_into_drawable_pieces(loop):
					continue
				usable.append(loop)
	return usable


# One silent resolution attempt for a loop that triangulates but is not strictly
# simple: merging it with itself makes Clipper resolve the crossings. What comes
# back is held to every gate again; what still fails is dropped without a node -
# never handed to the partitioner, which would print `Convex decomposing failed!`.
static func _append_resolved_collidable_loops(loop : PackedVector2Array,
			usable : Array[PackedVector2Array]) -> void:
	for piece in Geometry2D.merge_polygons(loop, loop):
		if Geometry2D.is_polygon_clockwise(piece):
			continue
		for sub in Geometry2DUtil.split_at_pinch_points(
				Geometry2DUtil.remove_duplicate_points(piece)):
			var cleaned := Geometry2DUtil.remove_collinear_points(sub)
			if cleaned.size() < 3:
				continue
			if Geometry2DUtil.get_polygon_area(cleaned) <= MINIMUM_COLLISION_AREA:
				continue
			if Geometry2D.triangulate_polygon(cleaned).is_empty():
				continue
			if not Geometry2DUtil.is_strictly_simple(cleaned):
				continue
			if not _decomposes_into_drawable_pieces(cleaned):
				continue
			usable.append(cleaned)


# The exact criterion the editor applies when it draws a CollisionPolygon2D: convex
# decomposition, then a triangulated fill per piece. A sliver left over from booleans -
# a band a fraction of a pixel wide between the stroke and the fill it hugs, as
# described in #396 - can pass every contour-level check and still decompose into
# near-zero pieces the fill rejects, logging `Invalid polygon data` on every redraw.
# The decompose call is silent whenever it succeeds; the gates above make the failing
# (printing) case all but impossible, and a contour that fails it here is dropped, so
# it prints once per recompute at worst - never once per redraw.
static func _decomposes_into_drawable_pieces(loop : PackedVector2Array) -> bool:
	var pieces := Geometry2D.decompose_polygon_in_convex(loop)
	if pieces.is_empty():
		return false
	for piece in pieces:
		if Geometry2D.triangulate_polygon(piece).is_empty():
			return false
	return true


# Subtracts every polygon in [param subtrahends] from [param minuend] and returns the
# parts of it which none of them covers.
# A subtrahend lying completely inside the remainder is postponed: subtracting it
# would turn the remainder into a polygon _with_ a hole, which then has to be sliced
# up into several polygons. Subtracting the overlapping ones first usually shrinks the
# remainder far enough for the postponed ones to overlap it as well, so it can stay in
# one piece. What is still enclosed once nothing else is left really is an island.
# With [param slice_around_islands] flagged off the remainder is left whole and the
# islands are returned alongside it, so both stay closed loops: a caller after the
# _contours_ of the remainder needs them intact, a caller after its _surface_ needs it
# sliced, because a [CollisionPolygon2D] cannot represent a hole.
static func _subtract_polygons(minuend : PackedVector2Array,
			subtrahends : Array[PackedVector2Array],
			slice_around_islands := true) -> Array[PackedVector2Array]:
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
			if not slice_around_islands:
				# only islands are left: each of them bounds the remainder just like the
				# remainder bounds them, so they are contours of it in their own right
				return remainder + postponed
			# only enclosed polygons are left: slice the remainder around them, in
			# stead of leaving it with a hole it cannot represent
			slice_polygons_with_holes(remainder, postponed)
			return remainder
		todo = postponed
	return remainder


## Returns the contours enclosing the area covered by [param polygons]: the outline of
## every solid they merge into first, followed by the holes those outlines enclose.
## [ScalableVectorShape2D] draws one [Line2D] along each of them, so its stroke follows
## the contour of a cutout just like it follows the contour of the shape itself.
## The holes are derived from the merged outlines only once the whole set is joined,
## because an area with a hole in it arrives here already sliced open around that hole -
## see [method slice_polygons_with_holes]. Reading a hole off the merge of a _pair_ in
## stead reports the hole of that pair: whatever the polygons merged after it fill up
## of that hole is then still reported as a hole which is not there anymore.
static func calculate_outlines(polygons : Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	if polygons.size() <= 1:
		return polygons

	var sources := polygons.duplicate()
	_merge_until_stable(polygons)

	var holes : Array[PackedVector2Array] = []
	for solid in polygons:
		for hole in _subtract_polygons(solid, sources, false):
			if get_polygon_area(hole) <= MINIMUM_HOLE_AREA:
				continue
			if not Geometry2D.is_polygon_clockwise(hole):
				# a hole runs against the winding order of the outline enclosing it
				hole.reverse()
			holes.append(hole)
	return polygons + holes


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


static func is_point_on_segment(p : Vector2, s1 : Vector2, s2: Vector2, r := 0.01) -> bool:
	return Geometry2D.segment_intersects_circle(s1, s2, p, r) > -1


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


static func get_segment_to_polyline_intersections(p0 : Vector2, p1 : Vector2,
		poly : PackedVector2Array) -> Array[Vector2]:
	var valid_intersections : Array[Vector2] = []
	if poly.size() < 2:
		return []
	for i in range(0, poly.size() - 1):
		var intersection = Geometry2D.segment_intersects_segment(p0, p1, poly[i], poly[i+1])
		if intersection != null:
			valid_intersections.append(intersection)
	return valid_intersections


static func get_polyline_segment(poly : PackedVector2Array, from : Vector2, to : Vector2) -> PackedVector2Array:
	var passed_from := false
	var segment := PackedVector2Array()
	for p_idx in range(0, poly.size() - 1):
		var p = poly[p_idx]
		var p1 = poly[p_idx + 1]
		if p.is_equal_approx(from) or p.is_equal_approx(to):
			if not passed_from:
				passed_from = true
				segment.append(p)
			else:
				break
		if passed_from:
			segment.append(p1)
	return segment


# returns true if the next point causes a loop (self intersection)
static func will_self_intersect_at(poly : Array[Vector2], next_point : Vector2) -> Variant:
	if poly.size() < 3:
		return null
	for i in range(0, poly.size() - 2):
		var intersection = Geometry2D.segment_intersects_segment(poly[-1], next_point, poly[i], poly[i+1])
		if intersection != null:
			return [i, intersection]
	return null


static func get_progress_ratio_for_point_on_curve(p : Vector2, c : Curve2D, max_stages := 5,
		tolerance_degrees := 4.0, r := 0.01) -> float:
	# Heuristic to find progress_ratio of cpc
	var d := 0.0
	var pts := c.tessellate(max_stages, tolerance_degrees)
	var p1 := pts[0]
	for i in range(1, pts.size()):
		if Geometry2DUtil.is_point_on_segment(p, p1, pts[i], r):
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


static func find_curve_segment_idx_for_point(curve : Curve2D, point : Vector2,
		max_stages := 5, tolerance_degrees := 4.0) -> int:
	for i in curve.point_count:
		# FIXME: assuming a loop
		var p1_idx := i + 1 if i < curve.point_count - 1 else 0
		var curve_segment := Curve2D.new()
		curve_segment.add_point(curve.get_point_position(i), Vector2.ZERO, curve.get_point_out(i))
		curve_segment.add_point(curve.get_point_position(p1_idx), curve.get_point_in(p1_idx))
		var polyline := curve_segment.tessellate(max_stages, tolerance_degrees)
		for j in range(polyline.size() - 1):
			if is_point_on_segment(point, polyline[j], polyline[j+1], 0.1):
				return i
	return -1


static func get_sliced_curve_segment(curve : Curve2D, before_segment : int, point_position : Vector2,
		max_stages := 5, tolerance_degrees := 4.0, r := 0.01) -> Curve2D:
	var curve_segment := Curve2D.new()
	curve_segment.add_point(curve.get_point_position(before_segment - 1))
	curve_segment.set_point_out(0, curve.get_point_out(before_segment - 1))
	curve_segment.add_point(curve.get_point_position(before_segment))
	curve_segment.set_point_in(1, curve.get_point_in(before_segment))
	var progress_ratio := Geometry2DUtil.get_progress_ratio_for_point_on_curve(
			point_position, curve_segment, max_stages, tolerance_degrees, r)
	return slice_bezier(
		curve_segment.get_point_position(0),
		curve_segment.get_point_out(0),
		curve_segment.get_point_in(1),
		curve_segment.get_point_position(1),
		progress_ratio
	)


static func get_reversed_curve(curve : Curve2D) -> Curve2D:
	var new_curve := Curve2D.new()
	for i in range(curve.point_count - 1, -1, -1):
		new_curve.add_point(curve.get_point_position(i), curve.get_point_out(i), curve.get_point_in(i))
	return new_curve


static func add_point_to_bezier(curve : Curve2D, placement_point : Vector2, before_segment : int,
		max_stages := 5, tolerance_degrees := 4.0, r := 0.01) -> Curve2D:
	var sliced_segment := get_sliced_curve_segment(curve, before_segment, placement_point,
			max_stages, tolerance_degrees, r)
	curve.add_point(placement_point, sliced_segment.get_point_in(1), sliced_segment.get_point_out(1), before_segment)
	curve.set_point_out(before_segment - 1, sliced_segment.get_point_out(0))
	curve.set_point_in(before_segment + 1, sliced_segment.get_point_in(2))

	return curve


static func cut_bezier_with_bezier(curve : Curve2D, cut : Curve2D,
		max_stages := 5, tolerance_degrees := 4.0) -> Array[Curve2D]:
	var halves : Array[Curve2D] = [
		Curve2D.new(), Curve2D.new()
	]

	var cut_start := cut.get_point_position(0)
	var cut_end := cut.get_point_position(cut.point_count - 1)
	var cut_start_segment_idx  := find_curve_segment_idx_for_point(curve, cut_start, max_stages, tolerance_degrees)
	var cut_end_segment_idx := find_curve_segment_idx_for_point(curve, cut_end, max_stages, tolerance_degrees)

	if cut_start_segment_idx == cut_end_segment_idx:
		if cut_start.distance_squared_to(curve.get_point_position(cut_start_segment_idx)) > cut_end.distance_squared_to(curve.get_point_position(cut_start_segment_idx)):
			var swap := cut_start
			cut_start = cut_end
			cut_end = swap
			cut = get_reversed_curve(cut)
		curve = add_point_to_bezier(curve.duplicate(), cut_start, cut_start_segment_idx + 1, max_stages, tolerance_degrees)
		cut_end = get_closest_point_on_polyline(cut_end, curve.tessellate(max_stages, tolerance_degrees))
		curve = add_point_to_bezier(curve, cut_end, cut_start_segment_idx + 2, max_stages, tolerance_degrees)
		cut.set_point_position(cut.point_count - 1, cut_end)

		for p_idx in range(0, cut_start_segment_idx + 1):
			halves[0].add_point(curve.get_point_position(p_idx))
			halves[0].set_point_in(p_idx, curve.get_point_in(p_idx))
			halves[0].set_point_out(p_idx, curve.get_point_out(p_idx))
		halves[0].add_point(cut_start)
		halves[0].set_point_in(cut_start_segment_idx + 1, curve.get_point_in(cut_start_segment_idx + 1))
		halves[0].set_point_out(cut_start_segment_idx + 1, cut.get_point_out(0))
		var seg_p_idx := halves[0].point_count
		for p_idx in range(1, cut.point_count):
			halves[0].add_point(cut.get_point_position(p_idx))
			halves[0].set_point_in(seg_p_idx, cut.get_point_in(p_idx))
			halves[0].set_point_out(seg_p_idx, cut.get_point_out(p_idx))
			seg_p_idx += 1
		for p_idx in range(cut_start_segment_idx + 2, curve.point_count):
			halves[0].add_point(curve.get_point_position(p_idx))
			if p_idx > cut_start_segment_idx + 2:
				halves[0].set_point_in(seg_p_idx, curve.get_point_in(p_idx))
			halves[0].set_point_out(seg_p_idx, curve.get_point_out(p_idx))
			seg_p_idx += 1
		halves[1].add_point(cut_start)
		halves[1].set_point_out(0, curve.get_point_out(cut_start_segment_idx + 1))
		halves[1].add_point(cut_end)
		halves[1].set_point_in(1, curve.get_point_in(cut_start_segment_idx + 2))
		cut = get_reversed_curve(cut)
		halves[1].set_point_out(1, cut.get_point_out(0))
		for p_idx in range(1, cut.point_count):
			halves[1].add_point(cut.get_point_position(p_idx))
			halves[1].set_point_in(p_idx + 1, cut.get_point_in(p_idx))
			halves[1].set_point_out(p_idx + 1, cut.get_point_out(p_idx))
		halves.sort_custom(func(a : Curve2D, b : Curve2D): return get_polygon_area(a.tessellate(max_stages, tolerance_degrees)) > get_polygon_area(b.tessellate(max_stages, tolerance_degrees)))
		return halves

	if cut_end_segment_idx < cut_start_segment_idx:
		var swap_idx := cut_start_segment_idx
		var swap := cut_start
		cut_start_segment_idx = cut_end_segment_idx
		cut_end_segment_idx = swap_idx
		cut_start = cut_end
		cut_end = swap
		cut = get_reversed_curve(cut)

	var cut_start_seg_slice := get_sliced_curve_segment(curve, cut_start_segment_idx + 1, cut_start, max_stages, tolerance_degrees)
	var cut_end_seg_slice := get_sliced_curve_segment(curve, cut_end_segment_idx + 1, cut_end, max_stages, tolerance_degrees)

	var seg_p_idx := 0
	for p_idx in range(0, cut_start_segment_idx + 1):
		halves[0].add_point(curve.get_point_position(p_idx))
		halves[0].set_point_out(seg_p_idx, curve.get_point_out(p_idx))
		halves[0].set_point_in(seg_p_idx, curve.get_point_in(p_idx))
		seg_p_idx += 1
	halves[0].add_point(cut.get_point_position(0))
	halves[0].set_point_out(seg_p_idx - 1, cut_start_seg_slice.get_point_out(0))
	halves[0].set_point_in(seg_p_idx, cut_start_seg_slice.get_point_in(1))
	halves[0].set_point_out(seg_p_idx, cut.get_point_out(0))
	seg_p_idx += 1
	for p_idx in range(1, cut.point_count):
		halves[0].add_point(cut.get_point_position(p_idx))
		halves[0].set_point_out(seg_p_idx, cut.get_point_out(p_idx))
		halves[0].set_point_in(seg_p_idx, cut.get_point_in(p_idx))
		seg_p_idx += 1
	halves[0].set_point_out(seg_p_idx - 1, cut_end_seg_slice.get_point_out(1))
	var memo_seg_p_idx = seg_p_idx
	for p_idx in range(cut_end_segment_idx + 1, curve.point_count):
		halves[0].add_point(curve.get_point_position(p_idx))
		halves[0].set_point_out(seg_p_idx, curve.get_point_out(p_idx))
		halves[0].set_point_in(seg_p_idx, curve.get_point_in(p_idx))
		seg_p_idx += 1
	halves[0].set_point_in(memo_seg_p_idx, cut_end_seg_slice.get_point_in(2))
	seg_p_idx = 0
	halves[1].add_point(cut_start)
	halves[1].set_point_out(seg_p_idx, cut_start_seg_slice.get_point_out(1))
	seg_p_idx += 1
	halves[1].add_point(curve.get_point_position(cut_start_segment_idx + 1))
	halves[1].set_point_in(seg_p_idx, cut_start_seg_slice.get_point_in(2))
	halves[1].set_point_out(seg_p_idx, curve.get_point_out(cut_start_segment_idx + 1))
	seg_p_idx += 1
	for p_idx in range(cut_start_segment_idx + 2, cut_end_segment_idx + 1):
		halves[1].add_point(curve.get_point_position(p_idx))
		halves[1].set_point_out(seg_p_idx, curve.get_point_out(p_idx))
		halves[1].set_point_in(seg_p_idx, curve.get_point_in(p_idx))
		seg_p_idx += 1
	halves[1].set_point_out(seg_p_idx - 1, cut_end_seg_slice.get_point_out(0))
	cut = get_reversed_curve(cut)
	halves[1].add_point(cut_end)
	halves[1].set_point_out(seg_p_idx, cut.get_point_out(0))
	memo_seg_p_idx = seg_p_idx
	seg_p_idx += 1
	for p_idx in range(1, cut.point_count):
		halves[1].add_point(cut.get_point_position(p_idx))
		halves[1].set_point_out(seg_p_idx, cut.get_point_out(p_idx))
		halves[1].set_point_in(seg_p_idx, cut.get_point_in(p_idx))
		seg_p_idx += 1
	halves[1].set_point_in(memo_seg_p_idx, cut_end_seg_slice.get_point_in(1))
	halves.sort_custom(func(a : Curve2D, b : Curve2D): return get_polygon_area(a.tessellate(max_stages, tolerance_degrees)) > get_polygon_area(b.tessellate(max_stages, tolerance_degrees)))
	return halves


static func get_curve_segment(segment_p1_idx : int, curve : Curve2D) -> Curve2D:
	var curve_segment := Curve2D.new()
	curve_segment.add_point(
		curve.get_point_position(segment_p1_idx),
		Vector2.ZERO,
		curve.get_point_out(segment_p1_idx)
	)
	var segment_p2_idx = (0 if segment_p1_idx == curve.point_count - 1
			else segment_p1_idx + 1)
	curve_segment.add_point(
		curve.get_point_position(segment_p2_idx),
		curve.get_point_in(segment_p2_idx)
	)
	return curve_segment


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

