@tool
class_name MoveLayerTool extends Object

static func is_move_backward_pressed(event : InputEvent) -> bool:
	return (
		event is InputEventKey and
		(event as InputEventKey).keycode == KEY_BRACKETLEFT and
		(event as InputEventKey).is_command_or_control_pressed() and
		(event as InputEventKey).pressed
	)


static func is_move_forward_pressed(event : InputEvent) -> bool:
	return (
		event is InputEventKey and
		(event as InputEventKey).keycode == KEY_BRACKETRIGHT and
		(event as InputEventKey).is_command_or_control_pressed() and
		(event as InputEventKey).pressed
	)


static func move_svs_backward(svs : ScalableVectorShape2D) -> void:
	_move_node_next_to_sibling(svs)


static func move_svs_forward(svs : ScalableVectorShape2D) -> void:
	_move_node_next_to_sibling(svs, true)


static func _move_node_next_to_sibling(svs : ScalableVectorShape2D, forward := false) -> void:
	if svs == EditorInterface.get_edited_scene_root():
		return
	var parent := svs.get_parent()
	if not is_instance_valid(parent):
		return
	var new_idx := -1
	var siblings = parent.get_children().filter(func(n): return n != svs and n is ScalableVectorShape2D)
	if forward:
		siblings.reverse()
	for sibling in siblings:
		if (sibling.get_index() > svs.get_index() and forward) or (sibling.get_index() < svs.get_index() and not forward):
			new_idx = sibling.get_index()
	if new_idx < 0:
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Move %s" % ("Forward" if forward else "Backward"))
	undo_redo.add_do_method(parent, "move_child", svs, new_idx)
	undo_redo.add_undo_method(parent, "move_child", svs, svs.get_index())
	undo_redo.commit_action()


