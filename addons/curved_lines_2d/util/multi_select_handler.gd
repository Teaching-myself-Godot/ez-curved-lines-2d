@tool
class_name MultiSelectHandler extends Object

static var _move_drag_start := Vector2.INF
static var selected_points : Dictionary[ScalableVectorShape2D, Array] = {}
static var selection_area := Rect2(Vector2.ZERO, Vector2.ZERO)
static var _stored_positions : Dictionary[int, Vector2] = {}
static var _stashed_selected_points : Array = []

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


static func move_points(event : InputEvent, svs : ScalableVectorShape2D, hover_point_idx : int,
			mouse_pos : Vector2, is_snapped_to_pixed : bool, snap_resolution : Vector2) -> bool:
	if hover_point_idx < 0:
		return false
	if hover_point_idx not in selection(svs):
		return false
	if  (
		event is InputEventMouseButton and
		(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	):
		if event.pressed:
			for i in selection(svs):
				_stored_positions[i] = svs.curve.get_point_position(i)
		else:
			var undo_redo := EditorInterface.get_editor_undo_redo()
			undo_redo.create_action("Move %d points" % get_point_count(svs))
			for i in _stored_positions.keys():
				undo_redo.add_do_method(svs.curve, "set_point_position", i, svs.curve.get_point_position(i))
				undo_redo.add_undo_method(svs.curve, "set_point_position", i, _stored_positions[i])
			undo_redo.commit_action(false)
			_stored_positions.clear()
		return true

	if  (
		event is InputEventMouseMotion and
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		var pos_before := svs.curve.get_point_position(hover_point_idx)
		svs.set_global_curve_point_position(mouse_pos, hover_point_idx, is_snapped_to_pixed, snap_resolution)
		var pos_after := svs.curve.get_point_position(hover_point_idx)
		var delta := pos_after - pos_before
		for i in selection(svs):
			if i == hover_point_idx:
				continue
			svs.curve.set_point_position(i, svs.curve.get_point_position(i) + delta)
		return true
	return false


static func delete_points(event : InputEvent, svs : ScalableVectorShape2D) -> bool:
	if get_point_count(svs) == 0:
		return false
	if (
		event is InputEventKey and
		(event as InputEventKey).keycode == KEY_DELETE and
		(event as InputEventKey).pressed
	):
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Delete %d points" % get_point_count(svs))
		var new_curve := Curve2D.new()
		var new_arcs := ScalableArcList.new()
		var new_deform : Dictionary[int, Bone2D] = {}
		for i in svs.curve.point_count:
			if i not in selection(svs):
				new_curve.add_point(svs.curve.get_point_position(i),
						svs.curve.get_point_in(i), svs.curve.get_point_out(i))
				var arc := (svs.arc_list.get_arc_for_point(i).duplicate(true)
					if svs.arc_list.get_arc_for_point(i) else null
				)
				if arc:
					arc.start_point = new_curve.point_count - 1
					new_arcs.add_arc(arc)
				if i in svs.deformation_map:
					new_deform[new_curve.point_count - 1] = svs.deformation_map[i]
		undo_redo.add_do_property(svs, 'curve', new_curve)
		undo_redo.add_do_property(svs, 'arc_list', new_arcs)
		undo_redo.add_do_property(svs, 'deformation_map', new_deform)
		undo_redo.add_undo_property(svs, 'curve', svs.curve)
		undo_redo.add_undo_property(svs, 'arc_list', svs.arc_list)
		undo_redo.add_undo_property(svs, 'deformation_map', svs.deformation_map)
		undo_redo.commit_action()
		clear_selection()
		return true
	return false


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
			if svs.is_curve_closed() and hover_point_idx == svs.curve.point_count - 1:
				selected_points[svs].erase(0)
			elif svs.is_curve_closed() and hover_point_idx == 0:
				selected_points[svs].erase(svs.curve.point_count - 1)
		else:
			selected_points[svs].append(hover_point_idx)
			if svs.is_curve_closed() and hover_point_idx == svs.curve.point_count - 1:
				selected_points[svs].append(0)
			elif svs.is_curve_closed() and hover_point_idx == 0:
				selected_points[svs].append(svs.curve.point_count - 1)

	if _is_drag_start(event, svs):
		_stashed_selected_points = selection(svs).duplicate()
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
		if i not in result and i not in _stashed_selected_points:
			selected_points[svs].erase(i)


static func deleselect_points_in_area(svs : ScalableVectorShape2D, area_check : Callable) -> void:
	if svs not in selected_points:
		selected_points[svs] = []
	var result := area_check.call(svs, selection_area.abs())
	for i in svs.curve.point_count:
		if i in result and i in selected_points[svs]:
			selected_points[svs].erase(i)
		if i not in result and i in _stashed_selected_points and i not in selected_points[svs]:
			selected_points[svs].append(i)


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
	_stored_positions.clear()


static func clear_selection_area() -> void:
	selection_area = Rect2(Vector2.ZERO, Vector2.ZERO)
