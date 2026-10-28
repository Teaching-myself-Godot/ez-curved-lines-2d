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
	if svs == EditorInterface.get_edited_scene_root():
		return
	var parent := svs.get_parent()
	if not is_instance_valid(parent):
		return
	var siblings : Array[Node] = parent.get_children().filter(_is_prev_svs.bind(svs))
	if siblings.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Move backward")
	undo_redo.add_do_method(parent, "move_child", svs, siblings.pop_back().get_index())
	undo_redo.add_undo_method(parent, "move_child", svs, svs.get_index())
	undo_redo.commit_action()



static func move_svs_forward(svs : ScalableVectorShape2D) -> void:
	if svs == EditorInterface.get_edited_scene_root():
		return
	var parent := svs.get_parent()
	if not is_instance_valid(parent):
		return
	var siblings : Array[Node] = parent.get_children().filter(_is_next_svs.bind(svs))
	if siblings.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Move forward")
	undo_redo.add_do_method(parent, "move_child", svs, siblings.pop_front().get_index())
	undo_redo.add_undo_method(parent, "move_child", svs, svs.get_index())
	undo_redo.commit_action()


static func _is_next_svs(n : Node, after_svs : ScalableVectorShape2D) -> bool:
	if n is ScalableVectorShape2D and n.get_index() > after_svs.get_index():
		return true
	return false


static func _is_prev_svs(n : Node, before_svs : ScalableVectorShape2D) -> bool:
	if n is ScalableVectorShape2D and n.get_index() < before_svs.get_index():
		return true
	return false
