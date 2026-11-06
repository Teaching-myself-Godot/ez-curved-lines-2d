@tool
class_name WidthCurveTool extends Object

const WIDTH_CURVE_EDIT_CLAMP_DISTANCE := 20
static var _hover_closest_point_on_curve : ClosestPointOnCurveMeta = null

static func handle_input(event : InputEvent, svs : ScalableVectorShape2D, mouse_pos : Vector2,
		vp_transform : Callable) -> bool:

	if event is InputEventMouseMotion:
		var closest_point_on_curve := svs.get_closest_point_on_curve(mouse_pos)
		if vp_transform.call(mouse_pos).distance_to(vp_transform.call(closest_point_on_curve.point_position)) < WIDTH_CURVE_EDIT_CLAMP_DISTANCE:
			_hover_closest_point_on_curve = closest_point_on_curve
		else:
			_hover_closest_point_on_curve = null
		return true
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_width_curve_point(svs, vp_transform)
		return true
	return false


static func draw(viewport_control : Control, svs : ScalableVectorShape2D,
		draw_hint : Callable, lmb_down : bool,
		vp_transform : Callable, svp_transform : Transform2D) -> void:

	var clamped_to_existing := false
	var hint := (
		"- Drag to make line thicker or thinner"
			if lmb_down else
		"- Click and drag to thin/thicken the stroke line"
	)

	if svs.line.width_curve:
		for i in svs.line.width_curve.point_count:
			var p := svs.line.width_curve.get_point_position(i)
			var cp := svs.get_closest_point_on_curve(
				svs.to_global(Geometry2DUtil.get_point_on_bezier_at_ratio(
						svs.get_deformed_curve(), p.x, svs.max_stages, svs.tolerance_degrees
			)))
			if _hover_closest_point_on_curve and vp_transform.call(cp.point_position * svp_transform).distance_to(vp_transform.call(_hover_closest_point_on_curve.point_position * svp_transform)) < WIDTH_CURVE_EDIT_CLAMP_DISTANCE:
				clamped_to_existing = true
				_draw_change_width_curve_icon(viewport_control, vp_transform.call(cp.point_position * svp_transform), cp.segment_rotation - svp_transform.get_rotation())
			else:
				_draw_change_width_curve_icon(viewport_control, vp_transform.call(cp.point_position * svp_transform), cp.segment_rotation - svp_transform.get_rotation(), Color.DIM_GRAY)
	if clamped_to_existing:
		hint += "\n- Right click to remove this width curve control point"
	elif _hover_closest_point_on_curve:
		_draw_change_width_curve_icon(viewport_control,
				vp_transform.call(_hover_closest_point_on_curve.point_position * svp_transform),
				_hover_closest_point_on_curve.segment_rotation - svp_transform.get_rotation()
		)
	draw_hint.call(viewport_control, hint)


static func _draw_change_width_curve_icon(viewport_control : Control, p : Vector2, segment_rotation : float,
		fill_color := Color.WHITE) -> void:
	var triangle := [14 * Vector2.UP, Vector2(10, -4), Vector2(-10, -4)].map(
			func(p1 : Vector2): return p + p1.rotated(segment_rotation)
	)
	var triangle2 := [14 * Vector2.UP, Vector2(10, -4), Vector2(-10, -4)].map(
			func(p1 : Vector2): return p + p1.rotated(segment_rotation + PI)
	)
	viewport_control.draw_polygon(Geometry2D.offset_polygon(triangle, 0.5)[0], [Color.BLACK])
	viewport_control.draw_polygon(triangle, [fill_color])
	viewport_control.draw_polygon(Geometry2D.offset_polygon(triangle2, 0.5)[0], [Color.BLACK])
	viewport_control.draw_polygon(triangle2, [fill_color])


static func _remove_width_curve_point(svs : ScalableVectorShape2D, vp_transform : Callable) -> void:
	if not is_instance_valid(svs.line):
		return
	if svs.line.width_curve == null:
		return
	var md_p : ClosestPointOnCurveMeta = _hover_closest_point_on_curve
	var clamped_to_existing := -1
	for i in svs.line.width_curve.point_count:
		var p := svs.line.width_curve.get_point_position(i)
		var cp := svs.get_closest_point_on_curve(
			svs.to_global(Geometry2DUtil.get_point_on_bezier_at_ratio(
					svs.get_deformed_curve(), p.x, svs.max_stages, svs.tolerance_degrees
		)))
		if vp_transform.call(cp.point_position).distance_to(vp_transform.call(md_p.point_position)) < WIDTH_CURVE_EDIT_CLAMP_DISTANCE:
			clamped_to_existing = i
			break
	if clamped_to_existing < 0:
		return
	var width_curve : Curve = svs.line.width_curve.duplicate(true)
	width_curve.remove_point(clamped_to_existing)
	if width_curve.point_count == 0:
		width_curve = null
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("remove width curve handle: " + str(svs))
	undo_redo.add_do_property(svs.line, 'width_curve', width_curve)
	undo_redo.add_undo_property(svs.line, 'width_curve', svs.line.width_curve.duplicate(true) if svs.line.width_curve else null)
	undo_redo.commit_action()
