@tool
class_name BasicFit
extends Object

const MAX_ANGLE_INBOUND_TO_OUTBOUND := deg_to_rad(30.0)
const MAX_CUMULATIVE_ANGLE_PER_SEGMENT := deg_to_rad(90.0)


static func prepare_polyline_segments(pts : PackedVector2Array, snap := 10.0,
		max_ang := MAX_ANGLE_INBOUND_TO_OUTBOUND, max_cum_ang := MAX_CUMULATIVE_ANGLE_PER_SEGMENT) -> Array[int]:
	if pts.size() < 4:
		return [0]
	var splits : Array[int] = [0]
	## any point p of which the angle between the inbound and outbound line p_a exceeds 30.0° will
	## become the start of a new segment
	for i in range(1, pts.size()):
		var prev_p := pts[i - 1]
		var p := pts[i]
		var next_p := pts[i + 1] if i < pts.size() - 1 else pts[0]
		if absf(prev_p.direction_to(p).angle_to(p.direction_to(next_p))) > max_ang:
			splits.append(i)
		if prev_p.distance_to(p) >= snap:
			if i - 1 not in splits:
				splits.append(i - 1)
			if i not in splits:
				splits.append(i)
	if pts[pts.size()-1].distance_to(pts[0]) >= snap and pts.size()-1 not in splits:
		splits.append(pts.size()-1)

	# any p of which the p_a bends in the opposite direction of the p_a' that came before it
	# or the difference in angle with the previous p_a(p[s_idx]) exceeds 45° will also become
	# the start of a new s_idx
	var cumulative_angle := 0.0
	var last_angle := 0.0
	var cumulative_distance := 0.0
	for i in range(1, pts.size()):
		var prev_p := pts[i - 1]
		var p := pts[i]
		var next_p := pts[i + 1] if i < pts.size() - 1 else pts[i]
		var cur_angle := prev_p.direction_to(p).angle_to(p.direction_to(next_p))
		cumulative_angle += cur_angle
		cumulative_distance += prev_p.distance_to(next_p)
		if (i not in splits and (absf(cumulative_angle) > max_cum_ang
					or is_equal_approx(absf(cumulative_angle), max_cum_ang)
					or (last_angle > 0.0 and cur_angle < 0.0)
					or (last_angle < 0.0 and cur_angle > 0.0)
			and prev_p.distance_to(p) > snap * 4.0
		)):
			splits.append(i)

		if i in splits:
			cumulative_angle = 0.0
			cumulative_distance = 0.0
		last_angle = cur_angle

	splits.sort()
	return splits


static func sum_distances(d_sum : Dictionary, point : Vector2) -> Dictionary:
	var d := point.distance_to(d_sum["prev"])
	return {
		"prev": point,
		"sum": d + d_sum["sum"]
	}


static func get_speculative_quadratic_control_point(polyline : PackedVector2Array, d : float) -> Vector2:
	if polyline.size() < 2:
		return polyline[0]
	if is_zero_approx(polyline[0].distance_to(polyline[-1])):
		return polyline[0] + polyline[-1] / 2.0
	var segment_start_point := polyline[0]
	var segment_end_point := polyline[-1]
	var halfway_point := (segment_start_point + segment_end_point) / 2.0
	var polyline_halfway_point := Geometry2DUtil.get_point_on_polyline_at_ratio(polyline, 0.5, d)
	var dir := halfway_point.direction_to(polyline_halfway_point)
	var distance := halfway_point.distance_to(polyline_halfway_point)
	return halfway_point + (distance * 2.422 * dir)


static func conjecture_curve_for_polyline(polyline : PackedVector2Array, poly_line_length : float) -> Curve2D:
	var q := get_speculative_quadratic_control_point(polyline, poly_line_length)
	var c := Curve2D.new()
	c.add_point(polyline[0])
	c.add_point(polyline[-1])
	if polyline.size() == 2:
		return c
	if polyline[0].direction_to(q).rotated(PI).is_equal_approx(polyline[-1].direction_to(q)):
		return c
	c.set_point_out(0, (q - polyline[0]) * (2.0 / (1.1*PI)))
	c.set_point_in(1, (q - polyline[-1]) * (2.0 / (1.1*PI)))
	return c


static func evaluate_curve_for_polyline(c : Curve2D, pts : PackedVector2Array, d_tot : float) -> float:
	var d := 0.0
	var deltas : Array[float] = [Geometry2DUtil.get_point_on_bezier_at_ratio(c, 0.0).distance_to(pts[0])]
	for i in range(1, pts.size()):
		d += pts[i-1].distance_to(pts[i])
		deltas.append(Geometry2DUtil.get_point_on_bezier_at_ratio(c, d / d_tot).distance_to(pts[i]))
	return deltas.reduce(func(a,b): return a + b, 0) / deltas.size()


static func rotate_p0_out(cs1 : Curve2D, unit : float) -> Curve2D:
	var cs = cs1.duplicate()
	cs.set_point_out(0, cs.get_point_out(0).rotated(deg_to_rad(unit)))
	return cs


static func rotate_p1_in(cs1 : Curve2D, unit : float) -> Curve2D:
	var cs = cs1.duplicate()
	cs.set_point_in(1, cs.get_point_in(1).rotated(deg_to_rad(unit)))
	return cs


static func fit_curve_segment_to_polyline_segment(segment : PackedVector2Array) -> Curve2D:
	var d : float = Array(segment).reduce(sum_distances, {"prev": segment[0], "sum": 0.0})["sum"]
	var cs := conjecture_curve_for_polyline(segment, d)
	var baseline_score := evaluate_curve_for_polyline(cs, segment, d)
	var tm := Time.get_ticks_msec()
	var lambdas : Array[Callable] = [
		rotate_p0_out, rotate_p0_out, rotate_p1_in,  rotate_p1_in
	]
	var lambda_idx : int = 0
	var unit : float = 3.0
	var sample_count = 1
	var best := baseline_score
	var score_before := baseline_score
	var best_fit := cs.duplicate()
	while unit > 0.05 and baseline_score > 0.3:
		var cs1 := lambdas[lambda_idx].call(cs, unit)
		var cs2 := lambdas[lambda_idx].call(cs, -unit)
		var new_score_1 := evaluate_curve_for_polyline(cs1, segment, d)
		var new_score_2 := evaluate_curve_for_polyline(cs2, segment, d)
		if new_score_1 < baseline_score:
			baseline_score = new_score_1
			cs = cs1
		elif new_score_2 < baseline_score:
			baseline_score = new_score_2
			cs = cs2
		else:
			if lambda_idx == lambdas.size() - 1:
				unit -= 0.1
				lambda_idx = 0
			else:
				lambda_idx += 1
		sample_count += 1
		if baseline_score < best:
			best_fit = cs.duplicate()
			best = baseline_score
	return best_fit


static func fit_curve_to_polyline(poly : PackedVector2Array, splits : Array[int]) -> Curve2D:
	var c := Curve2D.new()
	c.add_point(poly[0])
	for i in splits.size():
		var s_idx := splits[i]
		var next := splits[i + 1] if i + 1 < splits.size() else -2
		var segment := poly.slice(s_idx, next + 1)
		if next < 0:
			segment.append(poly[0])
		if segment.size() == 2:
			c.add_point(segment[1])
		else:
			var cs := fit_curve_segment_to_polyline_segment(segment)
			c.set_point_out(c.point_count - 1, cs.get_point_out(0))
			c.add_point(cs.get_point_position(1))
			c.set_point_in(c.point_count - 1, cs.get_point_in(1))
	return c
