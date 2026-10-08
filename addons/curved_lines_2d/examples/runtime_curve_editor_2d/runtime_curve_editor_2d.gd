@tool
class_name RuntimeCurveEditor2D extends Path2D

@export_group("Looks")
@export var outline_color := Color.WHITE
@export var outline_width := 1.0
@export_subgroup("Handles Default")
@export var handle_color := Color.WHITE
@export var handle_stroke_color := Color.BLACK
@export var handle_stroke_width := 1.0
@export var antialiased := false
@export_subgroup("Handles hovered")
@export var handle_hovered_color := Color.RED
@export var handle_hovered_stroke := Color.WHITE


@export_group("Curve settings")
@export var other_nodes : Array[Node2D]:
	set(on):
		other_nodes = on
		_update_parent_pts()

@export_range(1, 10) var max_stages := 5:
	set(ms):
		max_stages = ms
		_update_parent_pts()

@export_group("")
@export_range(0.0, 180.0) var tolerance_degrees := 4.0:
	set(td):
		tolerance_degrees = td
		_update_parent_pts()

var _hovered_idx := -1

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
		elif "points" in n and n.points is PackedVector2Array:
			n.points = curve.tessellate(max_stages, tolerance_degrees)
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
		if i == 0 and is_closed:
			c_i = curve.get_point_in(curve.point_count - 1)
		elif i == curve.point_count - 1 and is_closed:
			continue
		var fill := handle_hovered_color if _hovered_idx == i else handle_color
		var stroke := handle_stroke_color if _hovered_idx == i else handle_stroke_color
		draw_rect(Rect2(p - Vector2(5,5), Vector2(10,10)), fill, true, -1.0, antialiased)
		draw_rect(Rect2(p - Vector2(6,6), Vector2(12,12)), stroke, false, handle_stroke_width, antialiased)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			print(_hovered_idx)
			_handle_drag(event)
		else:
			_handle_hover(event)


func _handle_drag(event : InputEventMouseMotion) -> void:
	if _hovered_idx < 0:
		return
	curve.set_point_position(_hovered_idx, to_local(event.global_position))


func _handle_hover(event : InputEventMouseMotion) -> void:
	var before := _hovered_idx
	if _hovered_idx > -1:
		_hovered_idx = -1
	for i in curve.point_count:
		var p = curve.get_point_position(i)
		if Rect2(to_global(p) - Vector2(6,6), Vector2(12,12)).has_point(event.global_position):
			_hovered_idx = i
	if before != _hovered_idx:
		queue_redraw()


func _is_curve_closed() -> bool:
	var n = curve.point_count
	return n > 2 and curve.get_point_position(0).distance_squared_to(curve.get_point_position(n - 1)) < 0.00001
