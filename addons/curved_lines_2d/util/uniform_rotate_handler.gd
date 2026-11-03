class_name UniformRotateHandler extends Object

static var _drag_start := Vector2.INF
static var _prev_uniform_rotate_angle := 0.0
static var temp_pivot := Vector2.INF
static var _stashed_curve : Curve2D = null

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
				temp_pivot = Vector2.INF
				_prev_uniform_rotate_angle = 0.0
				_drag_start = Vector2.INF
				if _stashed_curve != null:
					var undo_redo := EditorInterface.get_editor_undo_redo()
					undo_redo.create_action("Rotate points")
					undo_redo.add_do_property(svs, "curve", svs.curve)
					undo_redo.add_undo_property(svs, "curve", _stashed_curve)
					undo_redo.commit_action(false)
		return true

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var use_cntr := Input.is_key_pressed(KEY_SHIFT) or svs.shape_type != ScalableVectorShape2D.ShapeType.PATH
			var rotation_origin = (
					temp_pivot
						if use_cntr else
					svs.global_position
			)
			var rotation_target := mouse_pos
			var ang := rotation_origin.angle_to_point(rotation_target) - rotation_origin.angle_to_point(_drag_start)
			if (event as InputEventMouseMotion).is_command_or_control_pressed():
				ang = snappedf(ang, deg_to_rad(45.0))
			if ang != _prev_uniform_rotate_angle:
				var drag_delta := ang - _prev_uniform_rotate_angle
				if use_cntr:
					svs.rotate_points_by(drag_delta, svs.to_local(rotation_origin), MultiSelectHandler.selection(svs))
				else:
					svs.rotate_points_by(drag_delta, Vector2.ZERO, MultiSelectHandler.selection(svs))

				_prev_uniform_rotate_angle = ang
		return true
	return false

