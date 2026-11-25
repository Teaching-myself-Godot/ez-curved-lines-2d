@tool
extends ScrollContainer

const HINT_LABEL_TEXT := "Geometric Operations"
const HINT_LABEL_SELECT_MORE_HINT := "- Select more shapes to apply %s -"

var AssignedGeometryListItemScene : PackedScene = preload("res://addons/curved_lines_2d/assigned_geometry_list_item.tscn")

func sync_svs_settings(svs : ScalableVectorShape2D, sel : Array) -> void:
	for ch in %AssignmentList.get_children():
		%AssignmentList.remove_child(ch)
		ch.queue_free()

	if sel.size() == 1:
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


func _get_selected_shapes() -> Array:
	var rt := EditorInterface.get_edited_scene_root()
	var sel := EditorInterface.get_selection().get_selected_nodes()
	return ([rt] if rt is ScalableVectorShape2D else [] + rt
		.find_children("*", "ScalableVectorShape2D", true, true)
		.filter(func(x): return x.owner == EditorInterface.get_edited_scene_root())
		.filter(func(x): return x in sel)
	)


func _on_clip_off_shapes_button_pressed() -> void:
	var sel := _get_selected_shapes()
	var clipper : ScalableVectorShape2D = sel.pop_front()
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(%ClipHintLabel.text)
	undo_redo.add_do_property(clipper, 'use_interect_when_clipping', true)
	undo_redo.add_do_property(clipper, 'use_union_in_stead_of_clipping', false)
	undo_redo.add_undo_property(clipper, 'use_interect_when_clipping', clipper.use_interect_when_clipping)
	undo_redo.add_undo_property(clipper, 'use_union_in_stead_of_clipping', clipper.use_union_in_stead_of_clipping)
	for svs : ScalableVectorShape2D in sel:
		if clipper not in svs.clip_paths:
			var orig_clip_paths := svs.clip_paths.duplicate(true)
			var new_clip_paths := svs.clip_paths.duplicate(true)
			new_clip_paths.append(clipper)
			for n in [svs.line, svs.polygon, svs.poly_stroke]:
				if is_instance_valid(n):
					undo_redo.add_do_reference(n)
					undo_redo.add_undo_property(n, 'visible', true)
			undo_redo.add_do_property(svs, 'clip_paths', new_clip_paths)
			undo_redo.add_undo_property(svs, 'clip_paths', orig_clip_paths)
	undo_redo.commit_action()


func _on_cut_out_shapes_button_pressed() -> void:
	var sel := _get_selected_shapes()
	var clipper : ScalableVectorShape2D = sel.pop_back()
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(%ClipHintLabel.text)
	undo_redo.add_do_property(clipper, 'use_interect_when_clipping', false)
	undo_redo.add_do_property(clipper, 'use_union_in_stead_of_clipping', false)
	undo_redo.add_undo_property(clipper, 'use_interect_when_clipping', clipper.use_interect_when_clipping)
	undo_redo.add_undo_property(clipper, 'use_union_in_stead_of_clipping', clipper.use_union_in_stead_of_clipping)
	for svs : ScalableVectorShape2D in sel:
		if clipper not in svs.clip_paths:
			var orig_clip_paths := svs.clip_paths.duplicate(true)
			var new_clip_paths := svs.clip_paths.duplicate(true)
			new_clip_paths.append(clipper)
			for n in [svs.line, svs.polygon, svs.poly_stroke]:
				if is_instance_valid(n):
					undo_redo.add_do_reference(n)
					undo_redo.add_undo_property(n, 'visible', true)
			undo_redo.add_do_property(svs, 'clip_paths', new_clip_paths)
			undo_redo.add_undo_property(svs, 'clip_paths', orig_clip_paths)
	undo_redo.commit_action()


func _on_merge_shapes_button_pressed() -> void:
	var sel := _get_selected_shapes()
	var merged_one : ScalableVectorShape2D = sel.pop_front()
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(%ClipHintLabel.text)
	var orig_clip_paths := merged_one.clip_paths.duplicate(true)
	var new_clip_paths := merged_one.clip_paths.duplicate(true)
	for svs : ScalableVectorShape2D in sel:
		if svs not in merged_one.clip_paths:
			new_clip_paths.append(svs)
			undo_redo.add_do_property(svs, 'use_interect_when_clipping', false)
			undo_redo.add_do_property(svs, 'use_union_in_stead_of_clipping', true)
			undo_redo.add_undo_property(svs, 'use_interect_when_clipping', svs.use_interect_when_clipping)
			undo_redo.add_undo_property(svs, 'use_union_in_stead_of_clipping', svs.use_union_in_stead_of_clipping)
	undo_redo.add_do_property(merged_one, 'clip_paths', new_clip_paths)
	undo_redo.add_undo_property(merged_one, 'clip_paths', orig_clip_paths)
	undo_redo.commit_action()


func _on_merge_shapes_button_mouse_entered() -> void:
	var sel := _get_selected_shapes()
	if sel.size() < 2:
		%ClipHintLabel.text = HINT_LABEL_SELECT_MORE_HINT % "merge"
	elif sel.size() == 2:
		%ClipHintLabel.text = "Merge " + sel[0].name + " with " + sel[1].name
	else:
		%ClipHintLabel.text = "Merge " + str(sel.size()) + " nodes"


func _on_merge_shapes_button_mouse_exited() -> void:
	%ClipHintLabel.text = HINT_LABEL_TEXT


func _on_cut_out_shapes_button_mouse_entered() -> void:
	var sel := _get_selected_shapes()
	if sel.size() < 2:
		%ClipHintLabel.text = HINT_LABEL_SELECT_MORE_HINT % "cutout"
	elif sel.size() == 2:
		%ClipHintLabel.text = "Cut " + sel[1].name + " out from " + sel[0].name
	else:
		%ClipHintLabel.text = "Cut " + sel.pop_back().name + " out from " + str(sel.size()) + " nodes"


func _on_cut_out_shapes_button_mouse_exited() -> void:
	%ClipHintLabel.text = HINT_LABEL_TEXT


func _on_clip_off_shapes_button_mouse_entered() -> void:
	var sel := _get_selected_shapes()
	if sel.size() < 2:
		%ClipHintLabel.text = HINT_LABEL_SELECT_MORE_HINT % "clip mask"
	elif sel.size() == 2:
		%ClipHintLabel.text = "Clip " + sel[0].name + " off of " + sel[1].name
	else:
		%ClipHintLabel.text = "Clip " + sel.pop_front().name + " off of " + str(sel.size()) + " nodes"


func _on_clip_off_shapes_button_mouse_exited() -> void:
	%ClipHintLabel.text = HINT_LABEL_TEXT


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ev := event as InputEventKey
	if ev.shift_pressed and ev.is_command_or_control_pressed() and ev.pressed:
		match (ev.keycode):
			KEY_EQUAL:
				_on_merge_shapes_button_pressed()
			KEY_MINUS:
				_on_cut_out_shapes_button_pressed()
			KEY_BACKSPACE:
				_on_clip_off_shapes_button_pressed()
