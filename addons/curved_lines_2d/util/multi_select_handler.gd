@tool
class_name MultiSelectHandler extends Object

static func is_selecting(event : InputEvent, svs : ScalableVectorShape2D,
			handle_has_hover : bool, hover_point_idx : int) -> bool:
	if handle_has_hover:
		if hover_point_idx < 0:
			return false
		else:
			return (
				event is InputEventMouseButton and
				(event as InputEventMouseButton).shift_pressed and
				(event as InputEventMouseButton).is_command_or_control_pressed()
			) or (
				event is InputEventMouseMotion and
				(event as InputEventMouseMotion).shift_pressed and
				(event as InputEventMouseMotion).is_command_or_control_pressed()
			)
	return (
		event is InputEventMouseMotion and
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and
		(event as InputEventMouseMotion).shift_pressed and
		svs.shape_type == ScalableVectorShape2D.ShapeType.PATH and
		not (event as InputEventMouseMotion).is_command_or_control_pressed()
	) or (
		event is InputEventMouseButton and
		(event as InputEventMouseButton).shift_pressed and
		(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and
		svs.shape_type == ScalableVectorShape2D.ShapeType.PATH and
		not (event as InputEventMouseButton).is_command_or_control_pressed()
	)


static func get_point_count() -> int:
	return 0
