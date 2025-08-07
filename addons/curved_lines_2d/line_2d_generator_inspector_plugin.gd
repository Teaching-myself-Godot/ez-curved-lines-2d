@tool
extends EditorInspectorPlugin

class_name  Line2DGeneratorInspectorPlugin

const GROUP_NAME_CURVE_SETTINGS := "Curve settings"


func _can_handle(obj) -> bool:
	return obj is DrawablePath2D or obj is ScalableVectorShape2D


func _parse_begin(object: Object) -> void:
	if object is DrawablePath2D:
		var warning_label := Label.new()
		warning_label.text = "⚠️ DrawablePath2D is Deprecated"
		add_custom_control(warning_label)
		var button : Button = Button.new()
		button.text = "Convert to ScalableVectorShape2D"
		add_custom_control(button)
		button.pressed.connect(func(): _on_convert_button_pressed(object))
	if object is ScalableVectorShape2D and object.shape_type != ScalableVectorShape2D.ShapeType.PATH:
		var button : Button = Button.new()
		button.text = "Convert to Path*"
		button.tooltip_text = "Pressing this button will change the way it is edited to Path mode."
		add_custom_control(button)
		button.pressed.connect(func(): _on_convert_to_path_button_pressed(object, button))
	if object is ScalableVectorShape2D:
		var button : Button = Button.new()
		button.text = "Export as PNG*"
		button.tooltip_text = "The export will only contain this node and its children,
				assigned nodes outside this subtree will not be drawn."
		add_custom_control(button)
		button.pressed.connect(func(): _on_export_png_button_pressed(object))
	if object is ScalableVectorShape2D:
		var button : Button = Button.new()
		button.text = "Export as baked scene*"
		button.tooltip_text = "The export will only contain this node and its children,
				assigned nodes outside this subtree will not be drawn.\n
				Warning: AnimationPlayer will not be included."
		add_custom_control(button)
		button.pressed.connect(func(): _on_export_baked_scene_pressed(object))


func _parse_group(object: Object, group: String) -> void:
	if group == GROUP_NAME_CURVE_SETTINGS and object is ScalableVectorShape2D:
		var key_frame_form = load("res://addons/curved_lines_2d/batch_insert_curve_point_key_frames_inspector_form.tscn").instantiate()
		key_frame_form.scalable_vector_shape_2d = object
		add_custom_control(key_frame_form)


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if name == "line" and (object is  ScalableVectorShape2D):
		var assign_stroke_inspector_form = load("res://addons/curved_lines_2d/assign_stroke_inspector_form.tscn").instantiate()
		assign_stroke_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_stroke_inspector_form)
	elif name == "polygon" and (object  is ScalableVectorShape2D):
		var assign_fill_inspector_form = load("res://addons/curved_lines_2d/assign_fill_inspector_form.tscn").instantiate()
		assign_fill_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_fill_inspector_form)
	elif name == "collision_polygon" and (object is ScalableVectorShape2D):
		if object.collision_polygon == null:
			return true
		var assign_collision_inspector_form = load("res://addons/curved_lines_2d/assign_collision_inspector_form.tscn").instantiate()
		assign_collision_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_collision_inspector_form)
	elif name == "collision_object" and (object is ScalableVectorShape2D):
		var assign_collision_inspector_form = load("res://addons/curved_lines_2d/assign_collision_object_inspector_form.tscn").instantiate()
		assign_collision_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_collision_inspector_form)
	elif name == "navigation_region" and (object is ScalableVectorShape2D):
		var assign_nav_form = load("res://addons/curved_lines_2d/assign_navigation_region_inspector_form.tscn").instantiate()
		assign_nav_form.scalable_vector_shape_2d = object as ScalableVectorShape2D
		add_custom_control(assign_nav_form)
	return false


func _on_convert_button_pressed(orig : DrawablePath2D):
	var replacement := ScalableVectorShape2D.new()
	replacement.transform = orig.transform
	replacement.tolerance_degrees = orig.tolerance_degrees
	replacement.max_stages = orig.max_stages
	replacement.lock_assigned_shapes = orig.lock_assigned_shapes
	replacement.update_curve_at_runtime = orig.update_curve_at_runtime
	if orig.curve:
		replacement.curve = orig.curve
	if is_instance_valid(orig.line):
		replacement.line = orig.line
	if is_instance_valid(orig.polygon):
		replacement.polygon = orig.polygon
	if is_instance_valid(orig.collision_polygon):
		replacement.collision_polygon = orig.collision_polygon
	orig.replace_by(replacement, true)
	replacement.name = "ScalableVectorShape2D" if orig.name == "DrawablePath2D" else orig.name
	EditorInterface.call_deferred('edit_node', replacement)


func _on_convert_to_path_button_pressed(svs : ScalableVectorShape2D, button : Button):
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Change shape type to path for %s" % str(svs))
	undo_redo.add_do_property(svs, 'shape_type', ScalableVectorShape2D.ShapeType.PATH)
	undo_redo.add_undo_property(svs, 'shape_type', svs.shape_type)
	undo_redo.add_undo_property(svs, 'size', svs.size)
	undo_redo.add_undo_property(svs, 'rx', svs.rx)
	undo_redo.add_undo_property(svs, 'ry', svs.ry)
	undo_redo.add_undo_property(svs, 'offset', svs.offset)
	undo_redo.commit_action()
	button.hide()


func _on_export_png_button_pressed(svs : ScalableVectorShape2D) -> void:
	var dialog := EditorFileDialog.new()
	dialog.add_filter("*.png", "PNG image")
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.file_selected.connect(func(path): _export_png(svs, path, dialog))
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 400))


func _on_export_baked_scene_pressed(svs : ScalableVectorShape2D) -> void:
	var dialog := EditorFileDialog.new()
	dialog.add_filter("*.tscn", "Scene")
	dialog.current_file = svs.name.to_snake_case()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.current_path = svs.name.to_lower()
	dialog.file_selected.connect(func(path): _export_baked_scene(svs, path, dialog))
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 400))


func _export_png(svs : ScalableVectorShape2D, filename : String, dialog : Node) -> void:
	dialog.queue_free()
	var sub_viewport := SubViewport.new()
	EditorInterface.get_base_control().add_child(sub_viewport)
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var copied : ScalableVectorShape2D = svs.duplicate()
	sub_viewport.add_child(copied)
	var box = copied.get_bounding_box()
	var child_list := copied.get_children()
	var min_x = box.map(func(corner): return corner.x).min()
	var min_y = box.map(func(corner): return corner.y).min()
	var max_x = box.map(func(corner): return corner.x).max()
	var max_y = box.map(func(corner): return corner.y).max()

	while child_list.size() > 0:
		var child : Node = child_list.pop_back()
		child_list.append_array(child.get_children())
		if child is ScalableVectorShape2D:
			var box1 = child.get_bounding_box()
			var min_x1 = box1.map(func(corner): return corner.x).min()
			var min_y1 = box1.map(func(corner): return corner.y).min()
			var max_x1 = box1.map(func(corner): return corner.x).max()
			var max_y1 = box1.map(func(corner): return corner.y).max()
			min_x = min_x if min_x1 > min_x else min_x1
			min_y = min_y if min_y1 > min_y else min_y1
			max_x = max_x if max_x1 < max_x else max_x1
			max_y = max_y if box1[2].y < max_y else box1[2].y
	sub_viewport.canvas_transform.origin = -Vector2(min_x, min_y)
	sub_viewport.size = Vector2(max_x, max_y) - Vector2(min_x, min_y)
	await RenderingServer.frame_post_draw
	var img = sub_viewport.get_texture().get_image()
	img.save_png(filename)
	EditorInterface.get_resource_filesystem().scan()
	sub_viewport.queue_free()


func _export_baked_scene(svs : ScalableVectorShape2D, filepath : String, dialog : Node) -> void:
	dialog.queue_free()

	var svs_owner: Node = svs.owner
	var svs_parent: Node = svs.get_parent()
	var svs_index: int = svs.get_index()
	var scene: PackedScene = _create_baked_scene(svs, filepath)
	EditorInterface.open_scene_from_path(filepath)
	#var node: Node2D = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	#
	## We are replacing the entire branch.
	#svs_parent.remove_child(svs)
	#svs_parent.add_child(node, true)
	#svs_parent.move_child(node, svs_index)
	#
	#node.owner = svs_owner
	#node.scene_file_path = filepath
	#node.transform = svs.transform
	#
	#var undo_redo := EditorInterface.get_editor_undo_redo()
	#undo_redo.create_action("Export 'baked' scene")
	#undo_redo.add_do_method(svs_parent, "remove_child", svs)
	#undo_redo.add_undo_method(svs_parent, "remove_child", node)
	#undo_redo.add_do_method(svs_parent, "add_child", node, true)
	#undo_redo.add_undo_method(svs_parent, "add_child", svs, true)
	#undo_redo.add_do_method(svs_parent, "move_child", node, svs_index)
	#undo_redo.add_undo_method(svs_parent, "move_child", svs, svs_index)
	#undo_redo.add_do_property(node, "owner", svs_owner)
	#undo_redo.add_undo_property(svs, "owner", svs_owner)
	#undo_redo.add_do_method(self, "_replace_owner", node, null, svs_owner)
	#undo_redo.add_undo_method(self, "_replace_owner", svs, null, svs_owner)
	#undo_redo.add_do_reference(node)
	#undo_redo.add_undo_reference(svs)
	#undo_redo.commit_action(false)

# It will temporarily modify the current branch so we can create the baked scene.
func _create_baked_scene(svs : ScalableVectorShape2D, filepath: String) -> PackedScene:
	var svs_owner: Node = svs.owner
	var svs_children: Array[Node] = svs.get_children()
	var svs_ownership: Array[Node]
	var replace_map: Dictionary[Node, Node]
	var root := Node2D.new()
	root.name = svs.name
	replace_map[svs] = root

	while svs_children.size() > 0:
		var child: Node = svs_children.pop_back()

		if child is AnimationPlayer:
			continue

		svs_children.append_array(child.get_children())

		if child.owner == svs_owner:
			svs_ownership.append(child)

		if child is ScalableVectorShape2D:
			var node := Node2D.new()
			node.name = child.name
			node.unique_name_in_owner = child.unique_name_in_owner
			node.transform = child.transform
			replace_map[child] = node

	_replace_nodes(replace_map)

	for child in svs_ownership:
		if child in replace_map: # Got replaced, so update the replacement instead.
			replace_map[child].owner = root
		else:
			child.owner = root

	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, filepath, ResourceSaver.FLAG_NONE)

	# Undo modifications.
	_replace_nodes(replace_map, true)

	for child in svs_ownership:
		child.owner = svs_owner

	return ResourceLoader.load(filepath) as PackedScene

# Replace nodes in the map by the counterpart (key <-> value).
# NOTE: Important to know that doing "x.replace_by(y)"
# will also update children owner to y if they were owned by x.
func _replace_nodes(map: Dictionary[Node, Node], reverse: bool = false) -> void:
	if reverse:
		for node in map:
			map[node].replace_by(node, true)
	else:
		for node in map:
			node.replace_by(map[node], true)


# NOTE: When you have a instance of a scene in the Scene dock, they do contain
# all the same nodes from their original scene but they are hidden from the user.
# This is done through Node.owner, because Scene dock only display
# nodes owned by the root node.
func _replace_owner(node: Node, old_owner: Node, new_owner: Node) -> void:
	for child in node.get_children():
		if child.owner == old_owner:
			child.owner = new_owner

		_replace_owner(child, old_owner, new_owner)
