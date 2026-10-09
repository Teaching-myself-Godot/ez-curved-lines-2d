@tool
class_name RuntimeCurveEditor2D extends Path2D

@export_group("Looks")
@export var antialiased := false
@export_subgroup("Outline")
@export var outline_color := Color.WHITE
@export var outline_width := 1.0
@export_subgroup("Handles Default")
@export var handle_color := Color.WHITE
@export var handle_stroke_color := Color.BLACK
@export var handle_stroke_width := 1.0
@export_subgroup("Handles Hovered")
@export var handle_hovered_color := Color.RED
@export var handle_hovered_stroke := Color.WHITE
@export_subgroup("Handle Lines")
@export var handle_line_stroke := Color.BLACK
@export var handle_line_stroke_width := 1.0


@export_group("Curve settings")
@export var other_nodes : Array[Node2D]:
	set(on):
		other_nodes = on
		_update_parent_pts()

@export_range(1, 10) var max_stages := 5:
	set(ms):
		max_stages = ms
		_update_parent_pts()

@export_range(0.0, 180.0) var tolerance_degrees := 4.0:
	set(td):
		tolerance_degrees = td
		_update_parent_pts()

var _hovered_idx := -1
var _hovered_cp_in_idx := -1
var _hovered_cp_out_idx := -1


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
		var fitness_prep := BasicFit.prepare_polyline_segments(pts, _get_basic_fit_snap(pts))
		curve = BasicFit.fit_curve_to_polyline(pts, fitness_prep)


func _get_basic_fit_snap(poly : PackedVector2Array) -> float:
	var bounds := Geometry2DUtil.get_polygon_bounding_rect(poly)
	return (bounds.size.x + bounds.size.y) / 2.0


func _draw() -> void:
	if Engine.is_editor_hint():
		return
	var pts := Array(curve.tessellate(max_stages, tolerance_degrees))
	draw_polyline(pts, outline_color, outline_width, antialiased)

	var is_closed := _is_curve_closed()
	var result := []
	for i in range(curve.point_count):
		var p = curve.get_point_position(i)
		var c_i = curve.get_point_in(i)
		var c_o = curve.get_point_out(i)
		draw_line(p, p + c_i, handle_line_stroke, handle_line_stroke_width, antialiased)
		draw_line(p, p + c_o, handle_line_stroke, handle_line_stroke_width, antialiased)

		var ci_hovered := _hovered_cp_in_idx == i
		draw_circle(p + c_i, 5, handle_hovered_color if ci_hovered else handle_color, true, -1.0, antialiased)
		draw_circle(p + c_i, 5, handle_stroke_color if ci_hovered else handle_stroke_color, false, handle_stroke_width, antialiased)


		var co_hovered := _hovered_cp_out_idx == i
		draw_circle(p + c_o, 5, handle_hovered_color if co_hovered else handle_color, true, -1.0, antialiased)
		draw_circle(p + c_o, 5, handle_stroke_color if co_hovered else handle_stroke_color, false, handle_stroke_width, antialiased)


		var hovered := _hovered_idx == i
		draw_rect(Rect2(p - Vector2(5,5), Vector2(10,10)), handle_hovered_color if hovered else handle_color, true, -1.0, antialiased)
		draw_rect(Rect2(p - Vector2(5,5), Vector2(10,10)), handle_stroke_color if hovered else handle_stroke_color, false, handle_stroke_width, antialiased)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		_handle_button(event)
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_handle_drag(event)
		else:
			_handle_hover(event)


func _handle_button(event : InputEventMouseButton) -> void:
	if event.double_click:
		for i in curve.point_count:
			var p = curve.get_point_position(i)
			if Rect2(to_global(p) - Vector2(6,6), Vector2(12,12)).has_point(event.global_position):
				var ci := curve.get_point_in(i)
				var co := curve.get_point_out(i)
				if ci.is_equal_approx(Vector2.ZERO) and co.is_equal_approx(Vector2.ZERO):
					var intersections_before := Geometry2DUtil.get_self_intersections(curve.tessellate(max_stages, tolerance_degrees)).size()
					if i > 0:
						curve.set_point_in(i, (Vector2.RIGHT * 20.0) * global_scale)
					elif _is_curve_closed():
						curve.set_point_in(curve.point_count -1, (Vector2.RIGHT * 20.0) * global_scale)
					if i < curve.point_count - 1:
						curve.set_point_out(i, (Vector2.LEFT * 20.0) * global_scale)
					elif _is_curve_closed():
						curve.set_point_out(0, (Vector2.LEFT * 20.0) * global_scale)
					var intersections_after := Geometry2DUtil.get_self_intersections(curve.tessellate(max_stages, tolerance_degrees)).size()
					if intersections_after > intersections_before:
						if i > 0:
							curve.set_point_in(i, (Vector2.LEFT * 20.0) * global_scale)
						elif _is_curve_closed():
							curve.set_point_in(curve.point_count -1, (Vector2.LEFT * 20.0) * global_scale)
						if i < curve.point_count - 1:
							curve.set_point_out(i, (Vector2.RIGHT * 20.0) * global_scale)
						elif _is_curve_closed():
							curve.set_point_out(0, (Vector2.RIGHT * 20.0) * global_scale)
				else:
					curve.set_point_in(i, Vector2.ZERO)
					curve.set_point_out(i, Vector2.ZERO)



func _handle_drag(event : InputEventMouseMotion) -> void:
	if _hovered_idx > -1:
		if _is_curve_closed() and _hovered_idx == curve.point_count - 1:
			curve.set_point_position(0, to_local(event.global_position))
		curve.set_point_position(_hovered_idx, to_local(event.global_position))

	if _hovered_cp_in_idx > -1:
		curve.set_point_in(_hovered_cp_in_idx, to_local(event.global_position) - curve.get_point_position(_hovered_cp_in_idx))
		if Input.is_key_pressed(KEY_SHIFT):
			curve.set_point_out(_hovered_cp_in_idx, -(to_local(event.global_position) - curve.get_point_position(_hovered_cp_in_idx)))
	if _hovered_cp_out_idx > -1:

		curve.set_point_out(_hovered_cp_out_idx, to_local(event.global_position) - curve.get_point_position(_hovered_cp_out_idx))
		if Input.is_key_pressed(KEY_SHIFT):
			curve.set_point_in(_hovered_cp_out_idx, -(to_local(event.global_position) - curve.get_point_position(_hovered_cp_out_idx)))



func _handle_hover(event : InputEventMouseMotion) -> void:
	var before := _hovered_idx
	var before_cp_in := _hovered_cp_in_idx
	var before_cp_out := _hovered_cp_out_idx

	if _hovered_idx > -1:
		_hovered_idx = -1
	if _hovered_cp_in_idx > -1:
		_hovered_cp_in_idx = -1
	if _hovered_cp_out_idx > -1:
		_hovered_cp_out_idx = -1

	for i in curve.point_count:
		var p = curve.get_point_position(i)
		if Rect2(to_global(p) - Vector2(6,6), Vector2(12,12)).has_point(event.global_position):
			_hovered_idx = i

	if _hovered_idx < 0:
		for i in curve.point_count:
			var cp_in = curve.get_point_position(i) + curve.get_point_in(i)
			if to_global(cp_in).distance_to(event.global_position) <= 6.0:
				_hovered_cp_in_idx = i
			var cp_out = curve.get_point_position(i) + curve.get_point_out(i)
			if to_global(cp_out).distance_to(event.global_position) <= 6.0:
				_hovered_cp_out_idx = i

	if before != _hovered_idx or before_cp_in != _hovered_cp_in_idx or before_cp_out != _hovered_cp_out_idx:
		queue_redraw()


func _is_curve_closed() -> bool:
	var n = curve.point_count
	return n > 2 and curve.get_point_position(0).distance_squared_to(curve.get_point_position(n - 1)) < 0.0001
