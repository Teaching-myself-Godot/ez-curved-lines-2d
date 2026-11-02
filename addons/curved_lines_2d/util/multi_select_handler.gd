@tool
class_name MultiSelectHandler extends Object

static var selected_points : Dictionary[ScalableVectorShape2D, Array] = {}

static var selection_area := Rect2(Vector2.ZERO, Vector2.ZERO)

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


static func _is_drag_button_event(event : InputEvent, svs : ScalableVectorShape2D) -> bool:
	return (
		event is InputEventMouseButton and
		(event as InputEventMouseButton).shift_pressed and
		(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and
		svs.shape_type == ScalableVectorShape2D.ShapeType.PATH and
		not (event as InputEventMouseButton).is_command_or_control_pressed()
	)


static func _is_drag_start(event : InputEvent, svs : ScalableVectorShape2D) -> bool:
	return _is_drag_button_event(event, svs) and event.pressed


static func _is_drag_end(event : InputEvent, svs : ScalableVectorShape2D) -> bool:
	return _is_drag_button_event(event, svs) and not event.pressed


static func _is_dragging(event : InputEvent, svs : ScalableVectorShape2D) -> bool:
	return (
		event is InputEventMouseMotion and
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and
		(event as InputEventMouseMotion).shift_pressed and
		svs.shape_type == ScalableVectorShape2D.ShapeType.PATH and
		not (event as InputEventMouseMotion).is_command_or_control_pressed()
	)


static func is_selecting(event : InputEvent, svs : ScalableVectorShape2D,
			handle_has_hover : bool, hover_point_idx : int) -> bool:
	if handle_has_hover:
		return _is_ctrl_shift_held_on_point_handle(event, handle_has_hover, hover_point_idx)
	return _is_dragging(event, svs) or _is_drag_button_event(event, svs)


static func handle_selecting(event : InputEvent, svs : ScalableVectorShape2D,
			handle_has_hover : bool, hover_point_idx : int, area_check : Callable) -> void:
	if _is_ctrl_shift_click_on_point_handle(event, handle_has_hover, hover_point_idx):
		if svs not in selected_points:
			selected_points[svs] = []
		if hover_point_idx in selected_points[svs]:
			selected_points[svs].erase(hover_point_idx)
		else:
			selected_points[svs].append(hover_point_idx)
	if _is_drag_start(event, svs):
		selection_area.position = event.position
		selection_area.size = Vector2.ZERO
	if _is_dragging(event, svs):
		selection_area.size = event.position - selection_area.position
		if Input.is_key_pressed(KEY_ALT):
			deleselect_points_in_area(svs, area_check)
		else:
			select_points_in_area(svs, area_check)
	if _is_drag_end(event, svs):
		clear_selection_area()


static func select_points_in_area(svs : ScalableVectorShape2D, area_check : Callable) -> void:
	if svs not in selected_points:
		selected_points[svs] = []
	var result := area_check.call(svs, selection_area.abs())
	for i in svs.curve.point_count:
		if i in result and i not in selected_points[svs]:
			selected_points[svs].append(i)


static func deleselect_points_in_area(svs : ScalableVectorShape2D, area_check : Callable) -> void:
	if svs not in selected_points:
		selected_points[svs] = []
	var result := area_check.call(svs, selection_area.abs())
	for i in svs.curve.point_count:
		if i in result and i in selected_points[svs]:
			selected_points[svs].erase(i)


static func clear_selection_if_rmb_clicked(event : InputEvent, n : Node) -> bool:
	if (
		event is InputEventMouseButton and
		(event as InputEventMouseButton).pressed and
		(event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and
		n is ScalableVectorShape2D and n in selected_points and selected_points[n as ScalableVectorShape2D].size() > 0
	):
		clear_selection()
		return true
	return false


static func get_point_count(svs : ScalableVectorShape2D) -> int:
	return selection(svs).size()


static func selection(svs : ScalableVectorShape2D) -> Array:
	if svs not in selected_points:
		return []
	return selected_points[svs]


static func clear_selection() -> void:
	selected_points.clear()


static func clear_selection_area() -> void:
	selection_area = Rect2(Vector2.ZERO, Vector2.ZERO)
