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
