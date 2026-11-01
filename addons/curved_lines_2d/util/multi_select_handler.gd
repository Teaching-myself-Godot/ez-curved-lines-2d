@tool
class_name MultiSelectHandler extends Object

static var selected_points : Dictionary[ScalableVectorShape2D, Array] = {}

static func _is_ctrl_shift_held_on_point_handle(event : InputEvent,
			handle_has_hover : bool, hover_point_idx : int) -> bool:
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


static func _is_ctrl_shift_click_on_point_handle(event : InputEvent,
			handle_has_hover : bool, hover_point_idx : int):
	return (
		_is_ctrl_shift_held_on_point_handle(event, handle_has_hover, hover_point_idx)
			and
		(event is InputEventMouseButton) and
		(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and
		(event as InputEventMouseButton).pressed
	)


static func is_selecting(event : InputEvent, svs : ScalableVectorShape2D,
			handle_has_hover : bool, hover_point_idx : int) -> bool:
	if handle_has_hover:
		return _is_ctrl_shift_held_on_point_handle(event, handle_has_hover, hover_point_idx)
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


static func handle_selecting(event : InputEvent, svs : ScalableVectorShape2D,
			handle_has_hover : bool, hover_point_idx : int) -> void:
	if _is_ctrl_shift_click_on_point_handle(event, handle_has_hover, hover_point_idx):
		if svs not in selected_points:
			selected_points[svs] = []
		if hover_point_idx in selected_points[svs]:
			selected_points[svs].erase(hover_point_idx)
		else:
			selected_points[svs].append(hover_point_idx)


static func get_point_count(svs : ScalableVectorShape2D) -> int:
	return selection(svs).size()


static func selection(svs : ScalableVectorShape2D) -> Array:
	if svs not in selected_points:
		return []
	return selected_points[svs]


static func clear_selection() -> void:
	selected_points.clear()
