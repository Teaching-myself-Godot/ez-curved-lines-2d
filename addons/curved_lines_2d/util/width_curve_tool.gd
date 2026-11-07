@tool
class_name WidthCurveTool extends Object

const WIDTH_CURVE_EDIT_CLAMP_DISTANCE := 20
static var _hover_closest_point_on_curve : ClosestPointOnCurveMeta = null
static var _stashed_width_curve : Curve = null
static var _clamped_to_existing := -1
static var _drag_start := Vector2.INF

static func handle_input(event : InputEvent, svs : ScalableVectorShape2D, mouse_pos : Vector2,
		vp_transform : Callable, on_cancel : Callable, is_snapped_to_pixel : bool, snap_resolution : Vector2) -> bool:

	mouse_pos = mouse_pos.snapped(snap_resolution) if is_snapped_to_pixel else mouse_pos
	var closest_point_on_curve := svs.get_closest_point_on_curve(mouse_pos)
	var distance_to_mouse : float = vp_transform.call(mouse_pos).distance_to(vp_transform.call(closest_point_on_curve.point_position))
	if event is InputEventMouseMotion:
		if closest_point_on_curve.before_segment < svs.curve.point_count:
			if ((not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and distance_to_mouse < WIDTH_CURVE_EDIT_CLAMP_DISTANCE)
					or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
				_hover_closest_point_on_curve = closest_point_on_curve
			else:
				_hover_closest_point_on_curve = null
				_clamped_to_existing = -1
		else:
			_hover_closest_point_on_curve = null
			_clamped_to_existing = -1
		if _drag_start != Vector2.INF  and _hover_closest_point_on_curve:
				_change_width_curve(svs, vp_transform, mouse_pos)
		return true

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_drag_start = Vector2.INF
			if  vp_transform.call(mouse_pos).distance_to(vp_transform.call(closest_point_on_curve.point_position)) < WIDTH_CURVE_EDIT_CLAMP_DISTANCE:
				_remove_width_curve_point(svs, vp_transform)
			else:
				on_cancel.call()

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and distance_to_mouse < WIDTH_CURVE_EDIT_CLAMP_DISTANCE:
			_stashed_width_curve = svs.line.width_curve.duplicate(true) if svs.line.width_curve else null
			_clamped_to_existing = _find_clamp_index(svs, vp_transform)
			_drag_start = mouse_pos

		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_drag_start = Vector2.INF
			_hover_closest_point_on_curve = null
			var undo_redo := EditorInterface.get_editor_undo_redo()
			undo_redo.create_action("Change width curve")
			if svs.line.width_curve:
				undo_redo.add_do_property(svs.line, 'width_curve', svs.line.width_curve.duplicate(true))
			else:
				undo_redo.add_do_property(svs.line, 'width_curve', null)
			if _stashed_width_curve:
				undo_redo.add_undo_property(svs.line, 'width_curve', _stashed_width_curve)
			else:
				undo_redo.add_undo_property(svs.line, 'width_curve', null)
			undo_redo.commit_action()
			_stashed_width_curve = null
		return true
	return false


static func draw(viewport_control : Control, svs : ScalableVectorShape2D,
		draw_hint : Callable, lmb_down : bool,
		vp_transform : Callable, svp_transform : Transform2D, mouse_pos : Vector2,
		is_snapped_to_pixel : bool, snap_resolution : Vector2) -> void:

	var clamped_to_existing := false
	var hint := (
		"- Drag to make line thicker or thinner"
			if lmb_down and _drag_start != Vector2.INF else
		"- Click and drag to thin/thicken the stroke line"
	) if _hover_closest_point_on_curve  else (
		"- Hover over a line to make it thicker or thinner"
	)

	if svs.line.width_curve:
		for i in svs.line.width_curve.point_count:
			var p := svs.line.width_curve.get_point_position(i)
			if svs.is_curve_closed() and is_equal_approx(p.x, 1.0):
				continue
			var cp := svs.get_closest_point_on_curve(
				svs.to_global(Geometry2DUtil.get_point_on_bezier_at_ratio(
						svs.get_deformed_curve(), p.x, svs.max_stages, svs.tolerance_degrees
			)))
			if _hover_closest_point_on_curve and vp_transform.call(cp.point_position * svp_transform).distance_to(vp_transform.call(_hover_closest_point_on_curve.point_position * svp_transform)) < WIDTH_CURVE_EDIT_CLAMP_DISTANCE:
				clamped_to_existing = true
				_draw_change_width_curve_icon(viewport_control, vp_transform.call(cp.point_position * svp_transform), cp.segment_rotation - svp_transform.get_rotation())
			else:
				_draw_change_width_curve_icon(viewport_control, vp_transform.call(cp.point_position * svp_transform), cp.segment_rotation - svp_transform.get_rotation(), Color.DIM_GRAY)
	if clamped_to_existing and not lmb_down:
		hint += "\n- Right click to remove this width curve control point"
	elif _hover_closest_point_on_curve and not lmb_down:
		_draw_change_width_curve_icon(viewport_control,
				vp_transform.call(_hover_closest_point_on_curve.point_position * svp_transform),
				_hover_closest_point_on_curve.segment_rotation - svp_transform.get_rotation()
		)
	if _drag_start != Vector2.INF and _hover_closest_point_on_curve:
		var orig := vp_transform.call(_hover_closest_point_on_curve.point_position * svp_transform)
		if is_snapped_to_pixel:
			mouse_pos = mouse_pos.snapped(snap_resolution)
		viewport_control.draw_line(orig, vp_transform.call(mouse_pos), svs.shape_hint_color, 3.0, true)
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
	match_start_end_point(svs, width_curve)
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("remove width curve handle: " + str(svs))
	undo_redo.add_do_property(svs.line, 'width_curve', width_curve)
	undo_redo.add_undo_property(svs.line, 'width_curve', svs.line.width_curve.duplicate(true) if svs.line.width_curve else null)
	undo_redo.commit_action()


static func _change_width_curve(svs : ScalableVectorShape2D, vp_transform : Callable, mouse_pos : Vector2) -> void:
	if not is_instance_valid(svs.line):
		return

	var md_p : ClosestPointOnCurveMeta = _hover_closest_point_on_curve
	if md_p.before_segment >= svs.curve.point_count:
		return
	var progress_ratio := Geometry2DUtil.get_progress_ratio_for_point_on_curve(
			md_p.local_point_position, svs.get_deformed_curve(), svs.max_stages, svs.tolerance_degrees,
			0.1
	)
	if progress_ratio < 0.0:
		return


	var new_value := md_p.local_point_position.distance_to(svs.to_local(mouse_pos)) / (svs.stroke_width * 0.5)
	var width_curve := Curve.new()
	if svs.line.width_curve == null:
		width_curve.add_point(Vector2(progress_ratio, 1.0))
	else:
		width_curve = svs.line.width_curve.duplicate(true)
		if new_value > width_curve.max_value:
			width_curve.max_value = new_value

		if _clamped_to_existing > -1:
			width_curve.set_point_offset(_clamped_to_existing, progress_ratio)
			width_curve.set_point_value(_clamped_to_existing, new_value)
		else:
			width_curve.add_point(Vector2(progress_ratio, new_value))
	match_start_end_point(svs, width_curve)
	svs.line.width_curve = width_curve
	_clamped_to_existing = _find_clamp_index(svs, vp_transform)


static func match_start_end_point(svs : ScalableVectorShape2D, width_curve : Curve):
	if width_curve and svs.is_curve_closed() and not is_equal_approx(width_curve.sample(0.0), width_curve.sample(1.0)):
		var end_idx := -1
		for i in width_curve.point_count:
			if is_equal_approx(width_curve.get_point_position(i).x, 1.0):
				end_idx = i
				break
		if end_idx > -1:
			width_curve.set_point_value(end_idx, width_curve.sample(0.0))
		else:
			width_curve.add_point(Vector2(1.0, width_curve.sample(0.0)))


static func _find_clamp_index(svs : ScalableVectorShape2D, vp_transform : Callable) -> int:
	if not _hover_closest_point_on_curve or not is_instance_valid(svs.line) or not svs.line.width_curve:
		return -1
	for i in svs.line.width_curve.point_count:
		var p := svs.line.width_curve.get_point_position(i)
		var cp := svs.get_closest_point_on_curve(
			svs.to_global(Geometry2DUtil.get_point_on_bezier_at_ratio(
					svs.get_deformed_curve(), p.x, svs.max_stages, svs.tolerance_degrees
		)))
		if vp_transform.call(cp.point_position).distance_to(vp_transform.call(_hover_closest_point_on_curve.point_position)) < WIDTH_CURVE_EDIT_CLAMP_DISTANCE:
			return i
	return -1
