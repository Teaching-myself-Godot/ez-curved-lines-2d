class_name UniformRotateHandler extends Object

static var _drag_start := Vector2.INF
static var _prev_uniform_rotate_angle := 0.0
static var temp_pivot := Vector2.INF
static var _stashed_curve : Curve2D = null
static var temp_pivot_hint := Vector2.INF

static func clear_settings() -> void:
	_drag_start = Vector2.INF
	_prev_uniform_rotate_angle = 0.0
	temp_pivot = Vector2.INF
	_stashed_curve = null
	temp_pivot_hint = Vector2.INF


static func handle_input(event : InputEvent, svs : ScalableVectorShape2D, mouse_pos : Vector2,
			is_snapped_to_pixel : bool, snap_resolution : Vector2) -> bool:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			if (event as InputEventMouseButton).alt_pressed:
				temp_pivot = mouse_pos.snapped(snap_resolution) if is_snapped_to_pixel else mouse_pos
			else:
				_drag_start = mouse_pos
				_prev_uniform_rotate_angle = 0.0
				temp_pivot = svs.to_global(svs.get_center()) if temp_pivot == Vector2.INF else temp_pivot
				_stashed_curve = svs.curve.duplicate(true)
		else:
			if _drag_start != Vector2.INF:
				_prev_uniform_rotate_angle = 0.0
				_drag_start = Vector2.INF
				if _stashed_curve != null:
					var undo_redo := EditorInterface.get_editor_undo_redo()
					undo_redo.create_action("Rotate points")
					undo_redo.add_do_property(svs, "curve", svs.curve.duplicate(true))
					undo_redo.add_undo_property(svs, "curve", _stashed_curve)
					undo_redo.commit_action(false)
					_stashed_curve = null
		return true

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _stashed_curve == null:
				_stashed_curve = svs.curve.duplicate(true)
			var use_temp_pivot := Input.is_key_pressed(KEY_SHIFT) or svs.shape_type != ScalableVectorShape2D.ShapeType.PATH
			var rotation_origin = (
					temp_pivot
						if use_temp_pivot else
					svs.global_position
			)
			var rotation_target := mouse_pos
			var ang := rotation_origin.angle_to_point(rotation_target) - rotation_origin.angle_to_point(_drag_start)
			if (event as InputEventMouseMotion).is_command_or_control_pressed():
				ang = snappedf(ang, deg_to_rad(5.0))
			if ang != _prev_uniform_rotate_angle:
				var drag_delta := ang - _prev_uniform_rotate_angle
				if use_temp_pivot:
					svs.rotate_points_by(drag_delta, svs.to_local(rotation_origin), MultiSelectHandler.selection(svs))
				else:
					svs.rotate_points_by(drag_delta, Vector2.ZERO, MultiSelectHandler.selection(svs))

				_prev_uniform_rotate_angle = ang
		elif (event as InputEventMouseMotion).alt_pressed:
			temp_pivot_hint = mouse_pos.snapped(snap_resolution) if is_snapped_to_pixel else mouse_pos
		else:
			temp_pivot_hint = Vector2.INF
		return true
	return false


static func draw(viewport_control : Control, svs : ScalableVectorShape2D,
		draw_hint : Callable, lmb_down : bool, ctrl_pressed : bool,
		vp_transform : Callable, svp_transform : Transform2D) -> void:
	if lmb_down:
		var hint_text := "- Drag to rotate all points (left mouse button held)"
		if svs.shape_type == ScalableVectorShape2D.ShapeType.PATH:
			if Input.is_key_pressed(KEY_SHIFT):
				hint_text += "\n- Rotating around the temporary pivot (Shift held)"
			else:
				hint_text += "\n- Hold Shift to rotate around the temporary pivot"
		if ctrl_pressed:
			hint_text += "\n- Rotating in steps of 5° (Ctrl held)"
		else:
			hint_text += "\n- Hold Ctrl to rotate in steps of 5°"
		draw_hint.call(viewport_control, hint_text)
	else:
		var hint_text := "- Drag Left Mouse Button to rotate all points"
		if Input.is_key_pressed(KEY_ALT):
			hint_text += "\n- Left Click to change temporary pivot position (Alt held)"
		else:
			hint_text += "\n- Alt + Left Click to change temporary pivot position"
		draw_hint.call(viewport_control, hint_text +
				"\n- Press Q to return to normal editing")
	if lmb_down:
		var rotation_origin = svs.global_position
		if (Input.is_key_pressed(KEY_SHIFT) or
				svs.shape_type != ScalableVectorShape2D.ShapeType.PATH
		):
			rotation_origin = UniformRotateHandler.temp_pivot
		var rotation_target := EditorInterface.get_editor_viewport_2d().get_mouse_position()
		if ctrl_pressed:
			var ang := snapped(rotation_origin.angle_to_point(rotation_target), deg_to_rad(5.0))
			var dst := rotation_origin.distance_to(rotation_target)
			rotation_target = rotation_origin + Vector2.RIGHT.rotated(ang) * dst
		viewport_control.draw_line(
			vp_transform.call(rotation_origin * svp_transform),
			vp_transform.call(rotation_target), svs.shape_hint_color, 1, true)
