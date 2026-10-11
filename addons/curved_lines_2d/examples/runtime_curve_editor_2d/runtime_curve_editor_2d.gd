@tool
class_name RuntimeCurveEditor2D extends Path2D

@export_group("Looks")
@export var antialiased := false:
	set(aa):
		antialiased = aa
		queue_redraw()

@export_subgroup("Outline")
@export var outline_color := Color.WHITE:
	set(oc):
		outline_color = oc
		queue_redraw()
@export var outline_width := 1.0:
	set(ow):
		outline_width = ow
		queue_redraw()

@export_subgroup("Handles Default")
@export_range(2.0, 100.0, 0.5, "or_greater") var handle_size := 6.0:
	set(hs):
		handle_size = hs
		queue_redraw()
@export var handle_color := Color.WHITE:
	set(hc):
		handle_color = hc
		queue_redraw()
@export var handle_stroke_color := Color.BLACK:
	set(hsc):
		handle_stroke_color = hsc
		queue_redraw()
@export var handle_stroke_width := 1.0:
	set(hsw):
		handle_stroke_width = hsw
		queue_redraw()

@export_subgroup("Handles Hovered")
@export var handle_hovered_color := Color.RED:
	set(hhc):
		handle_hovered_color = hhc
		queue_redraw()
@export var handle_hovered_stroke := Color.WHITE:
	set(hhs):
		handle_hovered_stroke = hhs
		queue_redraw()

@export_subgroup("Handle Lines")
@export var handle_line_stroke := Color.BLACK:
	set(hls):
		handle_line_stroke = hls
		queue_redraw()
@export var handle_line_stroke_width := 1.0:
	set(hlsw):
		handle_line_stroke_width = hlsw
		queue_redraw()

@export_group("Curve settings")
@export_range(1, 10) var max_stages := 5:
	set(ms):
		max_stages = ms
		_update_parent_pts()
@export_range(0.0, 180.0) var tolerance_degrees := 4.0:
	set(td):
		tolerance_degrees = td
		_update_parent_pts()

@export_group("Assigned Nodes")
@export var other_nodes : Array[Node2D]:
	set(on):
		other_nodes = on
		_update_parent_pts()

var _hovered_idx := -1
var _hovered_cp_in_idx := -1
var _hovered_cp_out_idx := -1
var _hover_segment_point := Vector2.INF

func _enter_tree() -> void:
	if not is_instance_valid(get_parent()):
		push_error("invalid parent")
	elif "curve" in get_parent():
		curve = get_parent().curve.duplicate(true)
		get_parent().curve = curve
	elif "polygon" in get_parent() and get_parent().polygon is PackedVector2Array:
		_fit_curve_to_points(get_parent().polygon)
	elif "points" in get_parent() and get_parent().points is PackedVector2Array:
		_fit_curve_to_points(get_parent().points)
	else:
		push_warning("Parent node type not supported: ", get_parent())
	get_parent().set_meta("_edit_lock_", true)
	if not curve.changed.is_connected(_update_parent_pts):
		curve.changed.connect(_update_parent_pts)
	_update_parent_pts()


func _update_parent_pts() -> void:
	for n in [get_parent()] + other_nodes:
		if not is_instance_valid(n):
			return
		elif "polygon" in n and n.polygon is PackedVector2Array:
			n.polygon = curve.tessellate(max_stages, tolerance_degrees)
			(n as CanvasItem).queue_redraw()
		elif "points" in n and n.points is PackedVector2Array:
			var pts := curve.tessellate(max_stages, tolerance_degrees)
			if "closed" in n:
				n.closed = _is_curve_closed()
				n.points = pts.slice(0, -1) if _is_curve_closed() else pts
			else:
				n.points = pts
		elif "_update_curve" in n:
			n._update_curve()
	queue_redraw()


func _fit_curve_to_points(pts : PackedVector2Array) -> void:
	if not pts.is_empty() and curve.point_count == 0:
		var fitness_prep := prepare_polyline_segments(pts, _get_basic_fit_snap(pts))
		curve = fit_curve_to_polyline(pts, fitness_prep)


func _get_basic_fit_snap(poly : PackedVector2Array) -> float:
	var bounds := get_polygon_bounding_rect(poly)
	return (bounds.size.x + bounds.size.y) / 2.0


func _draw() -> void:
	if Engine.is_editor_hint():
		return
	var pts := Array(curve.tessellate(max_stages, tolerance_degrees))
	if pts.size() > 1:
		draw_polyline(pts, outline_color, outline_width, antialiased)

	var is_closed := _is_curve_closed()
	var result := []
	for i in range(curve.point_count):
		var p = to_local(to_global(curve.get_point_position(i)).snapped(Vector2.ONE))
		var c_i = curve.get_point_in(i)
		var c_o = curve.get_point_out(i)
		if not c_i.is_equal_approx(Vector2.ZERO):
			draw_line(p, p + c_i, handle_line_stroke, handle_line_stroke_width, antialiased)

		if not c_o.is_equal_approx(Vector2.ZERO):
			draw_line(p, p + c_o, handle_line_stroke, handle_line_stroke_width, antialiased)

		if not c_o.is_equal_approx(Vector2.ZERO):
			var co_hovered := _hovered_cp_out_idx == i
			draw_circle(p + c_o, handle_size, handle_hovered_color if co_hovered else handle_color, true, -1.0, antialiased)
			draw_circle(p + c_o, handle_size, handle_hovered_stroke if co_hovered else handle_stroke_color, false, handle_stroke_width, antialiased)

		if not c_i.is_equal_approx(Vector2.ZERO):
			var ci_hovered := _hovered_cp_in_idx == i
			draw_circle(p + c_i, handle_size, handle_hovered_color if ci_hovered else handle_color, true, -1.0, antialiased)
			draw_circle(p + c_i, handle_size, handle_hovered_stroke if ci_hovered else handle_stroke_color, false, handle_stroke_width, antialiased)

	for i in range(curve.point_count):
		if _is_curve_closed() and i == curve.point_count - 1:
			continue
		var p = curve.get_point_position(i)
		var hovered := _hovered_idx == i
		draw_rect(Rect2(p - Vector2.ONE * handle_size, Vector2.ONE * handle_size * 2), handle_hovered_color if hovered else handle_color, true, -1.0, antialiased)
		draw_rect(Rect2(p - Vector2.ONE * handle_size, Vector2.ONE * handle_size * 2), handle_hovered_stroke if hovered else handle_stroke_color, false, handle_stroke_width, antialiased)

	if _hover_segment_point != Vector2.INF:
		draw_circle(_hover_segment_point, handle_size, handle_hovered_color, true, -1.0, antialiased)
		draw_circle(_hover_segment_point, handle_size, handle_hovered_stroke, false, handle_stroke_width, antialiased)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_dbl_click(event.global_position)
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click()
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_handle_drag(event.global_position)
		else:
			_handle_hover(event.global_position)


func _handle_dbl_click(g_cursor_pos : Vector2) -> void:
	if _hovered_idx == 0 and _is_curve_closed():
		_toggle_closing_point_control_points()
	elif _hovered_idx > -1:
		_toggle_control_points(_hovered_idx)
	elif _hover_segment_point:
		_add_point_at_hovered_point()


func _get_curve_segment(segment_p1_idx : int) -> Curve2D:
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


func _find_hovered_curve_segment_idx() -> int:
	var d_min := INF
	var before_segment := -1
	for i in curve.point_count:
		var seg := _get_curve_segment(i)
		var pt := get_closest_point_on_polyline(
			_hover_segment_point,
			seg.tessellate(max_stages, tolerance_degrees))
		var d := pt.distance_squared_to(_hover_segment_point)
		if d < d_min:
			d_min = d
			before_segment = i + 1
	return before_segment


func _add_point_at_hovered_point():
	var before_segment := _find_hovered_curve_segment_idx()
	if before_segment < 0:
		return
	var sliced_segment := get_sliced_curve_segment(
			curve, before_segment, _hover_segment_point,
			max_stages, tolerance_degrees)
	curve.add_point(_hover_segment_point, Vector2.ZERO, Vector2.ZERO, before_segment)

	if not (sliced_segment.get_point_out(0).is_equal_approx(Vector2.ZERO) and
			sliced_segment.get_point_in(2).is_equal_approx(Vector2.ZERO)):
		curve.set_point_in(before_segment, sliced_segment.get_point_in(1))
		curve.set_point_out(before_segment, sliced_segment.get_point_out(1))
		curve.set_point_out(before_segment - 1, sliced_segment.get_point_out(0))
		curve.set_point_in(before_segment + 1, sliced_segment.get_point_in(2))


func _toggle_closing_point_control_points() -> void:
	var n := curve.point_count - 1
	var ci := curve.get_point_in(n)
	var co := curve.get_point_out(0)
	if ci.is_equal_approx(Vector2.ZERO) and co.is_equal_approx(Vector2.ZERO):
		var intersections_before := get_self_intersections(curve.tessellate(max_stages, tolerance_degrees)).size()
		curve.set_point_in(n, (Vector2.RIGHT * handle_size * 3.0) * global_scale)
		curve.set_point_out(0, (Vector2.LEFT * handle_size * 3.0) * global_scale)
		var intersections_after := get_self_intersections(curve.tessellate(max_stages, tolerance_degrees)).size()
		if intersections_after > intersections_before:
			curve.set_point_in(n, (Vector2.LEFT * handle_size * 3.0) * global_scale)
			curve.set_point_out(0, (Vector2.RIGHT * handle_size * 3.0) * global_scale)
	else:
		curve.set_point_in(n, Vector2.ZERO)
		curve.set_point_out(0, Vector2.ZERO)
		curve.set_point_in(0, Vector2.ZERO)
		curve.set_point_out(n, Vector2.ZERO)


func _toggle_control_points(i : int) -> void:
	var ci := curve.get_point_in(i)
	var co := curve.get_point_out(i)
	if ci.is_equal_approx(Vector2.ZERO) and co.is_equal_approx(Vector2.ZERO):
		var intersections_before := get_self_intersections(curve.tessellate(max_stages, tolerance_degrees)).size()
		if i > 0:
			curve.set_point_in(i, (Vector2.RIGHT * handle_size * 3.0) * global_scale)
		if i < curve.point_count - 1:
			curve.set_point_out(i, (Vector2.LEFT * handle_size * 3.0) * global_scale)
		var intersections_after := get_self_intersections(curve.tessellate(max_stages, tolerance_degrees)).size()
		if intersections_after > intersections_before:
			if i > 0:
				curve.set_point_in(i, (Vector2.LEFT * handle_size * 3.0) * global_scale)
			if i < curve.point_count - 1:
				curve.set_point_out(i, (Vector2.RIGHT * handle_size * 3.0) * global_scale)
	else:
		curve.set_point_in(i, Vector2.ZERO)
		curve.set_point_out(i, Vector2.ZERO)


func _handle_right_click() -> void:
	if _hovered_cp_in_idx > -1:
		curve.set_point_in(_hovered_cp_in_idx, Vector2.ZERO)
	if _hovered_cp_out_idx > -1:
		curve.set_point_out(_hovered_cp_out_idx, Vector2.ZERO)
	if _hovered_idx > -1 and curve.point_count > 2:
		curve.remove_point(_hovered_idx)


func _handle_drag(g_cursor_pos : Vector2) -> void:
	var cursor_pos := to_local(g_cursor_pos)
	if _hovered_idx > -1:
		if _is_curve_closed() and _hovered_idx == 0:
			curve.set_point_position(curve.point_count - 1, cursor_pos)
		curve.set_point_position(_hovered_idx, cursor_pos)
	if _hovered_cp_in_idx > -1:
		curve.set_point_in(_hovered_cp_in_idx, cursor_pos - curve.get_point_position(_hovered_cp_in_idx))
		if Input.is_key_pressed(KEY_SHIFT):
			if _is_curve_closed() and _hovered_cp_in_idx == curve.point_count - 1:
				curve.set_point_out(0, -(cursor_pos - curve.get_point_position(_hovered_cp_in_idx)))
			elif _hovered_cp_in_idx < curve.point_count - 1:
				curve.set_point_out(_hovered_cp_in_idx, -(cursor_pos - curve.get_point_position(_hovered_cp_in_idx)))
	if _hovered_cp_out_idx > -1:
		curve.set_point_out(_hovered_cp_out_idx, cursor_pos - curve.get_point_position(_hovered_cp_out_idx))
		if Input.is_key_pressed(KEY_SHIFT):
			if _is_curve_closed() and _hovered_cp_out_idx == 0:
				curve.set_point_in(curve.point_count - 1, -(cursor_pos - curve.get_point_position(_hovered_cp_out_idx)))
			elif _hovered_cp_out_idx > 0:
				curve.set_point_in(_hovered_cp_out_idx, -(cursor_pos - curve.get_point_position(_hovered_cp_out_idx)))
	if _hover_segment_point != Vector2.INF:
		var idx := _find_hovered_curve_segment_idx()
		var segment_start_point := curve.get_point_position(idx - 1)
		var segment_end_point := curve.get_point_position(idx)
		var halfway_point := (segment_start_point + segment_end_point) / 2
		var dir := halfway_point.direction_to(cursor_pos)
		var distance := halfway_point.distance_to(cursor_pos)
		var quadratic_bezier_control_point := halfway_point + distance * 2 * dir
		var new_point_out := (quadratic_bezier_control_point - segment_start_point) * (2.0 / 3.0)
		var new_point_in := (quadratic_bezier_control_point - segment_end_point) * (2.0 / 3.0)
		curve.set_point_in(idx, new_point_in)
		curve.set_point_out(idx - 1, new_point_out)
		_hover_segment_point = cursor_pos


func _find_point_at(pos : Vector2) -> int:
	for i in curve.point_count:
		var p = curve.get_point_position(i)
		if to_global(p).distance_squared_to(pos) <= handle_size**2:
			return i
	return -1


func _handle_hover(g_cursor_pos : Vector2) -> void:
	var before := _hovered_idx
	var before_cp_in := _hovered_cp_in_idx
	var before_cp_out := _hovered_cp_out_idx
	var before_segment_hover_point := _hover_segment_point
	if _hovered_idx > -1:
		_hovered_idx = -1
	if _hovered_cp_in_idx > -1:
		_hovered_cp_in_idx = -1
	if _hovered_cp_out_idx > -1:
		_hovered_cp_out_idx = -1
	if _hover_segment_point != Vector2.INF:
		_hover_segment_point = Vector2.INF

	_hovered_idx = _find_point_at(g_cursor_pos)

	if _hovered_idx < 0:
		for i in curve.point_count:
			var cp_in = curve.get_point_position(i) + curve.get_point_in(i)
			if to_global(cp_in).distance_squared_to(g_cursor_pos) <= handle_size**2:
				_hovered_cp_in_idx = i
	if _hovered_cp_in_idx < 0 and _hovered_idx < 0:
		for i in curve.point_count:
			var cp_out = curve.get_point_position(i) + curve.get_point_out(i)
			if to_global(cp_out).distance_squared_to(g_cursor_pos) <= handle_size**2:
				_hovered_cp_out_idx = i
	if _hovered_cp_in_idx < 0 and _hovered_cp_out_idx < 0 and _hovered_idx < 0:
		var pts := curve.tessellate(max_stages, tolerance_degrees)
		var cpoc := get_closest_point_on_polyline(to_local(g_cursor_pos), pts)
		if to_global(cpoc).distance_squared_to(g_cursor_pos) <= handle_size**2:
			_hover_segment_point = cpoc

	if (before != _hovered_idx or before_cp_in != _hovered_cp_in_idx or
			before_cp_out != _hovered_cp_out_idx or
			before_segment_hover_point != _hover_segment_point):
		queue_redraw()


func _is_curve_closed() -> bool:
	var n = curve.point_count
	return n > 2 and curve.get_point_position(0).distance_squared_to(curve.get_point_position(n - 1)) < 0.00001


# -- Code below was copied in full from Scalable Vector Shapes 2D's BasicFit algorithm:
# https://github.com/Teaching-myself-Godot/ez-curved-lines-2d/blob/3.0.2/addons/curved_lines_2d/basic_fit.gd
# --

const MAX_ANGLE_INBOUND_TO_OUTBOUND := deg_to_rad(30.0)
const MAX_CUMULATIVE_ANGLE_PER_SEGMENT := deg_to_rad(90.0)

static func prepare_polyline_segments(pts : PackedVector2Array, snap := 10.0,
		max_ang := MAX_ANGLE_INBOUND_TO_OUTBOUND, max_cum_ang := MAX_CUMULATIVE_ANGLE_PER_SEGMENT) -> Array[int]:
	if pts.size() < 4:
		return [0]
	var splits : Array[int] = [0]

	var d_tot := 0.0
	var p_cnt := 0
	## any point p of which the angle between the inbound and outbound line p_a exceeds 30.0° will
	## become the start of a new segment
	for i in range(1, pts.size()):
		var prev_p := pts[i - 1]
		var p := pts[i]
		var next_p := pts[i + 1] if i < pts.size() - 1 else pts[0]
		var cur_dst := prev_p.distance_to(p)
		p_cnt += 1
		var d_avg := d_tot / float(p_cnt)
		d_tot += cur_dst

		if absf(prev_p.direction_to(p).angle_to(p.direction_to(next_p))) > max_ang:
			splits.append(i)
			d_tot = 0.0
			p_cnt = 0
		if cur_dst >= snap or (d_avg > 0.0 and cur_dst / d_avg > 5.0):
			if i - 1 not in splits:
				splits.append(i - 1)
				d_tot = 0.0
				p_cnt = 0
			if i not in splits:
				splits.append(i)
				d_tot = 0.0
				p_cnt = 0
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


static func get_speculative_quadratic_control_point(polyline : PackedVector2Array, d : float) -> Vector2:
	if polyline.size() < 2:
		return polyline[0]
	if is_zero_approx(polyline[0].distance_to(polyline[-1])):
		return polyline[0] + polyline[-1] / 2.0
	var segment_start_point := polyline[0]
	var segment_end_point := polyline[-1]
	var halfway_point := (segment_start_point + segment_end_point) / 2.0
	var polyline_halfway_point := get_point_on_polyline_at_ratio(polyline, 0.5, d)
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
	var deltas : Array[float] = [get_point_on_bezier_at_ratio(c, 0.0).distance_to(pts[0])]
	for i in range(1, pts.size()):
		d += pts[i-1].distance_to(pts[i])
		deltas.append(get_point_on_bezier_at_ratio(c, d / d_tot).distance_to(pts[i]))
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
	var d : float = get_polyline_length(segment)
	var cs := conjecture_curve_for_polyline(segment, d)
	var baseline_score := evaluate_curve_for_polyline(cs, segment, d)
	var lambdas : Array[Callable] = [
		rotate_p0_out, rotate_p0_out, rotate_p1_in,  rotate_p1_in
	]
	var lambda_idx : int = 0
	var unit : float = 3.0
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
		if baseline_score < best:
			best_fit = cs.duplicate()
			best = baseline_score
	return best_fit


static func fit_curve_to_polyline(poly : PackedVector2Array, splits : Array[int],
		minimum_points_per_segment_for_curve_fitting := 3) -> Curve2D:
	var c := Curve2D.new()
	c.add_point(poly[0])
	for i in splits.size():
		var s_idx := splits[i]
		var next := splits[i + 1] if i + 1 < splits.size() else -2
		var segment := poly.slice(s_idx, next + 1)
		if next < 0:
			segment = poly.slice(s_idx, poly.size())

		if segment.size() <= minimum_points_per_segment_for_curve_fitting:
			for j in range(1, segment.size()):
				c.add_point(segment[j])
		else:
			var cs := fit_curve_segment_to_polyline_segment(segment)
			c.set_point_out(c.point_count - 1, cs.get_point_out(0))
			c.add_point(cs.get_point_position(1))
			c.set_point_in(c.point_count - 1, cs.get_point_in(1))
	return c


# -- Code below was cherry picked from Scalable Vector Shapes 2D's Geometry2DUtil:
# https://github.com/Teaching-myself-Godot/ez-curved-lines-2d/blob/3.0.2/addons/curved_lines_2d/geometry_2d_util.gd
# --

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


static func get_closest_point_on_polyline(p : Vector2, poly_points : PackedVector2Array) -> Vector2:
	var closest_result := Vector2.INF
	for i in range(1, poly_points.size()):
		var p_a := poly_points[i - 1]
		var p_b := poly_points[i]
		var c_p := Geometry2D.get_closest_point_to_segment(p, p_a, p_b)
		if p.distance_to(c_p) < p.distance_to(closest_result):
			closest_result = c_p
	return closest_result


static func get_sliced_curve_segment(curve : Curve2D, before_segment : int, point_position : Vector2,
		max_stages := 5, tolerance_degrees := 4.0, r := 0.01) -> Curve2D:
	var curve_segment := Curve2D.new()
	curve_segment.add_point(curve.get_point_position(before_segment - 1))
	curve_segment.set_point_out(0, curve.get_point_out(before_segment - 1))
	curve_segment.add_point(curve.get_point_position(before_segment))
	curve_segment.set_point_in(1, curve.get_point_in(before_segment))
	var progress_ratio := get_progress_ratio_for_point_on_curve(
			point_position, curve_segment, max_stages, tolerance_degrees, r)
	return slice_bezier(
		curve_segment.get_point_position(0),
		curve_segment.get_point_out(0),
		curve_segment.get_point_in(1),
		curve_segment.get_point_position(1),
		progress_ratio
	)


# returns true if the next point causes a loop (self intersection)
static func will_self_intersect_at(poly : Array[Vector2], next_point : Vector2) -> Variant:
	if poly.size() < 3:
		return null
	for i in range(0, poly.size() - 2):
		var intersection = Geometry2D.segment_intersects_segment(poly[-1], next_point, poly[i], poly[i+1])
		if intersection != null:
			return [i, intersection]
	return null


static func get_self_intersections(poly_in : PackedVector2Array) -> Array[Vector2]:
	if poly_in.size() < 3:
		return []
	var intersections : Array[Vector2] = []
	var poly := poly_in.duplicate()
	poly.append(poly_in[0])
	for i in range(1, poly.size()):
		var next_point := poly[i] if i < poly.size() - 1 else poly[0]
		var result = will_self_intersect_at(poly.slice(0, i), next_point)
		if result and not poly[0].distance_squared_to(result[1]) < 0.0001:
			intersections.append(result[1])
	return intersections


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


static func get_point_on_bezier_at_ratio(c : Curve2D, ratio : float, max_stages := 5, tolerance_degrees := 4.0) -> Vector2:
	var pts := c.tessellate(max_stages, tolerance_degrees)
	var tot_d := c.get_baked_length()
	return get_point_on_polyline_at_ratio(pts, ratio, tot_d)


static func get_polyline_length(pts : PackedVector2Array) -> float:
	var d := 0.0
	for i in range(1, pts.size()):
		d += pts[i-1].distance_to(pts[i])
	return d


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


