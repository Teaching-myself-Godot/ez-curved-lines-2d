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
		button.text = "Convert into a ScalableVectorShape2D"
		add_custom_control(button)
		button.pressed.connect(func(): _on_convert_button_pressed(object))


func _parse_group(object: Object, group: String) -> void:
	if group == GROUP_NAME_CURVE_SETTINGS and object is ScalableVectorShape2D:
		var key_frame_form = preload("res://addons/curved_lines_2d/batch_insert_curve_point_key_frames_inspector_form.tscn").instantiate()
		key_frame_form.scalable_vector_shape_2d = object
		add_custom_control(key_frame_form)


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if name == "line" and (object is  ScalableVectorShape2D):
		var assign_stroke_inspector_form = preload("res://addons/curved_lines_2d/assign_stroke_inspector_form.tscn").instantiate()
		assign_stroke_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_stroke_inspector_form)
	elif name == "polygon" and (object  is ScalableVectorShape2D):
		var assign_fill_inspector_form = preload("res://addons/curved_lines_2d/assign_fill_inspector_form.tscn").instantiate()
		assign_fill_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_fill_inspector_form)
	elif name == "collision_polygon" and (object is ScalableVectorShape2D):
		var assign_collision_inspector_form = preload("res://addons/curved_lines_2d/assign_collision_inspector_form.tscn").instantiate()
		assign_collision_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_collision_inspector_form)
	elif name == "offset" and (object is ScalableRect2D):
		var button := Button.new()
		button.text = "Convert to Path"
		if EditorInterface.get_edited_scene_root() == object:
			button.disabled = true
			button.tooltip_text = "Cannot convert scene root node, to convert this shape, give it a parent node"
		else:
			button.tooltip_text = "Convert into a new ScalableVectorShape2D with the same shape as this ScalableRect2D"
			button.pressed.connect(func(): call_deferred('_on_convert_button_pressed', object))
		add_custom_control(button)
	return false


func _on_convert_button_pressed(orig : Node2D):
	EditorInterface.get_selection().clear()
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
	replacement.name = "ScalableVectorShape2D" if orig.name == "DrawablePath2D" else orig.name
	var undo_redo := EditorInterface.get_editor_undo_redo()
	var scene_root := EditorInterface.get_edited_scene_root()
	var parent = orig.get_parent()
	var idx = orig.get_index()
	undo_redo.create_action("Clone shape into new ScalableVectorShape2D")
	undo_redo.add_undo_reference(orig)
	undo_redo.add_do_reference(parent)
	undo_redo.add_undo_reference(parent)
	undo_redo.add_do_reference(replacement)
	undo_redo.add_do_method(parent, 'add_child', replacement, true)
	undo_redo.add_do_method(replacement, 'set_owner', scene_root)
	undo_redo.add_do_method(parent, 'move_child', replacement, idx)
	if is_instance_valid(replacement.polygon):
		undo_redo.add_do_method(replacement.polygon, 'reparent', replacement)
		undo_redo.add_do_method(replacement.polygon, 'set_owner', scene_root)
	if is_instance_valid(replacement.line):
		undo_redo.add_do_method(replacement.line, 'reparent', replacement)
		undo_redo.add_do_method(replacement.line, 'set_owner', scene_root)
	if is_instance_valid(replacement.collision_polygon):
		undo_redo.add_do_method(replacement.collision_polygon, 'reparent', replacement)
		undo_redo.add_do_method(replacement.collision_polygon, 'set_owner', scene_root)
	undo_redo.add_do_method(parent, 'remove_child', orig)
	undo_redo.add_undo_method(parent, 'add_child', orig, true)
	undo_redo.add_undo_method(orig, 'set_owner', scene_root)
	undo_redo.add_undo_method(parent, 'move_child', orig, idx)
	if is_instance_valid(orig.polygon):
		undo_redo.add_undo_method(orig.polygon, 'reparent', orig)
		undo_redo.add_undo_method(orig.polygon, 'set_owner', scene_root)
	if is_instance_valid(orig.line):
		undo_redo.add_undo_method(orig.line, 'reparent', orig)
		undo_redo.add_undo_method(orig.line, 'set_owner', scene_root)
	if is_instance_valid(orig.collision_polygon):
		undo_redo.add_undo_method(orig.collision_polygon, 'reparent', orig)
		undo_redo.add_undo_method(orig.collision_polygon, 'set_owner', scene_root)
	undo_redo.add_undo_method(parent, 'remove_child', replacement)
	undo_redo.commit_action()
