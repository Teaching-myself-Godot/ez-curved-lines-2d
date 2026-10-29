@tool
class_name SVSResourceUnlinker extends Object

static func is_unlink_hotkey_pressed(event : InputEvent) -> bool:
	return (
			event is InputEventKey and
			(event as InputEventKey).keycode == KEY_U and
			(event as InputEventKey).is_command_or_control_pressed() and
			(event as InputEventKey).pressed
	)


static func make_resources_unique(root_svs : ScalableVectorShape2D) -> void:
	var shapes := [root_svs] + root_svs.find_children("*", "ScalableVectorShape2D")
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Make resources unique on %d shapes" % shapes.size())
	for svs : ScalableVectorShape2D in shapes:
		undo_redo.add_do_property(svs, 'curve', svs.curve.duplicate(true))
		undo_redo.add_undo_property(svs, 'curve', svs.curve)
		undo_redo.add_do_property(svs, 'arc_list', svs.arc_list.duplicate(true))
		undo_redo.add_undo_property(svs, 'arc_list', svs.arc_list)
		if is_instance_valid(svs.polygon) and svs.polygon.texture:
			undo_redo.add_do_property(svs.polygon, 'texture', svs.polygon.texture.duplicate(true))
			undo_redo.add_undo_property(svs.polygon, 'texture', svs.polygon.texture)
	undo_redo.commit_action()
