@tool
extends ScrollContainer

var AssignedGeometryListItemScene : PackedScene = preload("res://addons/curved_lines_2d/assigned_geometry_list_item.tscn")

func sync_svs_settings(svs : ScalableVectorShape2D, sel : Array) -> void:
	for ch in %AssignmentList.get_children():
		%AssignmentList.remove_child(ch)
		ch.queue_free()

	if sel.size() > 1:
		%MergeShapesButton.disabled = false
		%CutOutShapesButton.disabled = false
		%ClipOffShapesButton.disabled = false
	else:
		%MergeShapesButton.disabled = true
		%CutOutShapesButton.disabled = true
		%ClipOffShapesButton.disabled = true
		for s : ScalableVectorShape2D in svs.clip_paths:
			var list_item := AssignedGeometryListItemScene.instantiate()
			list_item.svs = s
			%AssignmentList.add_child(list_item)
			list_item.remove_from_clip_paths.connect(_on_remove_from_clip_paths.bind(svs, s, sel))


func _on_remove_from_clip_paths(svs : ScalableVectorShape2D, cp : ScalableVectorShape2D, sel) -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Remove clip_path entry from shape")
	undo_redo.add_do_property(svs, 'clip_paths', svs.clip_paths.filter(func(c): return c != cp))
	undo_redo.add_undo_property(svs, 'clip_paths', svs.clip_paths.duplicate(true))
	undo_redo.add_do_method(svs, 'notify_assigned_node_change')
	undo_redo.add_undo_method(svs, 'notify_assigned_node_change')
	undo_redo.commit_action()
