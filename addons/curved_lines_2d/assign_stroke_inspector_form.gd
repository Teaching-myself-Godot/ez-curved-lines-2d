@tool
extends KeyframeButtonCapableInspectorFormBase

class_name AssignStrokeInspectorForm

var scalable_vector_shape_2d : ScalableVectorShape2D
var create_button : Button
var select_button : Button
var color_button : ColorPickerButton
var stroke_width_input : EditorSpinSlider

func _enter_tree() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	create_button = find_child("CreateStrokeButton")
	select_button = find_child("GotoLine2DButton")
	color_button = find_child("ColorPickerButton")
	if 'assigned_node_changed' in scalable_vector_shape_2d:
		scalable_vector_shape_2d.assigned_node_changed.connect(_on_svs_assignment_changed)
	stroke_width_input = _make_float_input("Stroke Width", 10.0, 0.0, 100.0, "px")
	find_child("StrokeWidthFloatFieldContainer").add_child(stroke_width_input)
	_on_svs_assignment_changed()
	stroke_width_input.value_changed.connect(_on_stroke_width_changed)
	_initialize_keyframe_capabilities()


func _on_svs_assignment_changed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.line):
		create_button.get_parent().hide()
		select_button.get_parent().show()
		create_button.disabled = true
		select_button.disabled = false
		stroke_width_input.value = scalable_vector_shape_2d.line.width
		color_button.color = scalable_vector_shape_2d.line.default_color
	else:
		create_button.get_parent().show()
		select_button.get_parent().hide()
		create_button.disabled = false
		select_button.disabled = true
		stroke_width_input.value = CurvedLines2D._get_default_stroke_width()
		color_button.color = CurvedLines2D._get_default_stroke_color()


func _on_stroke_width_changed(new_value : float) -> void:
	if not is_instance_valid(scalable_vector_shape_2d.line):
		return
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Adjust Line2D width for %s" % str(scalable_vector_shape_2d))
	undo_redo.add_do_property(scalable_vector_shape_2d.line, 'width', new_value)
	undo_redo.add_do_method(stroke_width_input, 'set_value_no_signal', new_value)
	undo_redo.add_undo_property(scalable_vector_shape_2d.line, 'width', scalable_vector_shape_2d.line.width)
	undo_redo.add_undo_method(stroke_width_input, 'set_value_no_signal', scalable_vector_shape_2d.line.width)
	undo_redo.commit_action()


func _on_color_picker_button_color_changed(color: Color) -> void:
	if not is_instance_valid(scalable_vector_shape_2d.line):
		return
	scalable_vector_shape_2d.line.default_color = color


func _on_goto_line_2d_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.line):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.line)


func _on_create_stroke_button_pressed():
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if is_instance_valid(scalable_vector_shape_2d.line):
		return

	var line_2d := Line2D.new()
	var root := EditorInterface.get_edited_scene_root()
	var undo_redo = EditorInterface.get_editor_undo_redo()
	line_2d.default_color = color_button.color
	line_2d.width = stroke_width_input.value
	line_2d.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line_2d.end_cap_mode = Line2D.LINE_CAP_ROUND
	line_2d.joint_mode = Line2D.LINE_JOINT_ROUND
	undo_redo.create_action("Add Line2D to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', line_2d, true)
	undo_redo.add_do_method(line_2d, 'set_owner', root)
	undo_redo.add_do_reference(line_2d)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'line', line_2d)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', line_2d)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'line', null)
	undo_redo.commit_action()


func _make_float_input(lbl : String, value : float, min_value : float, max_value : float, suffix : String) -> EditorSpinSlider:
	var x_slider := EditorSpinSlider.new()
	x_slider.value = value
	x_slider.min_value = min_value
	x_slider.max_value = max_value
	x_slider.suffix = suffix
	x_slider.label = lbl
	x_slider.editing_integer = false
	x_slider.step = 0.001
	return x_slider


func _on_add_stroke_width_key_frame_button_pressed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.line):
		add_key_frame(
			scalable_vector_shape_2d.line, "width", stroke_width_input.value
		)


func _on_add_stroke_color_key_frame_button_pressed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.line):
		add_key_frame(
			scalable_vector_shape_2d.line, "default_color", color_button.color
		)


func _on_key_frame_capabilities_changed():
	find_child("AddStrokeColorKeyFrameButton").visible = _is_key_frame_capable()
	find_child("AddStrokeWidthKeyFrameButton").visible = _is_key_frame_capable()


func _on_color_picker_button_toggled(toggled_on: bool) -> void:
	if not is_instance_valid(scalable_vector_shape_2d.line):
		return
	var undo_redo = EditorInterface.get_editor_undo_redo()
	if toggled_on:
		undo_redo.create_action("Adjust Line2D default_color for %s" % str(scalable_vector_shape_2d))
		undo_redo.add_undo_property(scalable_vector_shape_2d.line, 'default_color', scalable_vector_shape_2d.line.default_color)
		undo_redo.add_undo_property(color_button, 'color', scalable_vector_shape_2d.line.default_color)
	else:
		undo_redo.add_do_property(scalable_vector_shape_2d.line, 'default_color', color_button.color)
		undo_redo.add_do_property(color_button, 'color', color_button.color)
		undo_redo.commit_action(false)
