@tool
extends KeyframeButtonCapableInspectorFormBase

class_name AssignStrokeInspectorForm

var scalable_vector_shape_2d : ScalableVectorShape2D
var stroke_width_input : EditorSpinSlider

var begin_cap_button_map = {}
var end_cap_button_map = {}
var joint_button_map = {}

func _enter_tree() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if 'assigned_node_changed' in scalable_vector_shape_2d:
		scalable_vector_shape_2d.assigned_node_changed.connect(_on_svs_assignment_changed)
	stroke_width_input = _make_float_input("Stroke Width", 10.0, 0.0, 100.0, "px")
	%StrokeWidthFloatFieldContainer.add_child(stroke_width_input)
	begin_cap_button_map[Line2D.LineCapMode.LINE_CAP_NONE] = %BeginNoCapToggleButton
	begin_cap_button_map[Line2D.LineCapMode.LINE_CAP_BOX] = %BeginBoxCapToggleButton
	begin_cap_button_map[Line2D.LineCapMode.LINE_CAP_ROUND] = %BeginRoundCapToggleButton
	end_cap_button_map[Line2D.LineCapMode.LINE_CAP_NONE] = %EndNoCapToggleButton
	end_cap_button_map[Line2D.LineCapMode.LINE_CAP_BOX] = %EndBoxCapToggleButton
	end_cap_button_map[Line2D.LineCapMode.LINE_CAP_ROUND] = %EndRoundCapToggleButton
	joint_button_map[Line2D.LineJointMode.LINE_JOINT_SHARP] = %LineJointSharpToggleButton
	joint_button_map[Line2D.LineJointMode.LINE_JOINT_BEVEL] = %LineJointBevelToggleButton
	joint_button_map[Line2D.LineJointMode.LINE_JOINT_ROUND] = %LineJointRoundToggleButton
	_on_svs_assignment_changed()
	stroke_width_input.value_changed.connect(_on_stroke_width_changed)
	_initialize_keyframe_capabilities()


func _on_svs_assignment_changed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.line):
		%CreateStrokeButton.get_parent().hide()
		%GotoLine2DButton.get_parent().show()
		%CreateStrokeButton.disabled = true
		%GotoLine2DButton.disabled = false
		stroke_width_input.value = scalable_vector_shape_2d.line.width
		%ColorPickerButton.color = scalable_vector_shape_2d.line.default_color
		begin_cap_button_map[scalable_vector_shape_2d.line.begin_cap_mode].button_pressed = true
		end_cap_button_map[scalable_vector_shape_2d.line.end_cap_mode].button_pressed = true
		joint_button_map[scalable_vector_shape_2d.line.joint_mode].button_pressed = true
	else:
		%CreateStrokeButton.get_parent().show()
		%GotoLine2DButton.get_parent().hide()
		%CreateStrokeButton.disabled = false
		%GotoLine2DButton.disabled = true
		stroke_width_input.value = CurvedLines2D._get_default_stroke_width()
		%ColorPickerButton.color = CurvedLines2D._get_default_stroke_color()
		begin_cap_button_map[CurvedLines2D._get_default_begin_cap()].button_pressed = true
		end_cap_button_map[CurvedLines2D._get_default_end_cap()].button_pressed = true
		joint_button_map[CurvedLines2D._get_default_joint_mode()].button_pressed = true
	printerr("TODO: refactor stroke properties")
	if is_instance_valid(scalable_vector_shape_2d.poly_stroke):
		%CreatePolyStrokeButton.get_parent().hide()
		%GotoPolygon2DButton.get_parent().show()
		%CreatePolyStrokeButton.disabled = true
		%GotoPolygon2DButton.disabled = false
	else:
		%CreatePolyStrokeButton.get_parent().show()
		%GotoPolygon2DButton.get_parent().hide()
		%CreatePolyStrokeButton.disabled = false
		%GotoPolygon2DButton.disabled = true

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


func _on_goto_polygon_2d_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.poly_stroke):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.poly_stroke)


func _get_selected_begin_cap_mode() -> Line2D.LineCapMode:
	for map_key : Line2D.LineCapMode in begin_cap_button_map.keys():
		if begin_cap_button_map[map_key].button_pressed:
			return map_key
	return CurvedLines2D._get_default_begin_cap()


func _get_selected_end_cap_mode() -> Line2D.LineCapMode:
	for map_key : Line2D.LineCapMode in end_cap_button_map.keys():
		if end_cap_button_map[map_key].button_pressed:
			return map_key
	return CurvedLines2D._get_default_end_cap()


func _get_selected_joint_mode() -> Line2D.LineJointMode:
	for map_key : Line2D.LineJointMode in joint_button_map.keys():
		if joint_button_map[map_key].button_pressed:
			return map_key
	return CurvedLines2D._get_default_joint_mode()


func _on_create_stroke_button_pressed():
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if is_instance_valid(scalable_vector_shape_2d.line):
		return

	var line_2d := Line2D.new()
	var root := EditorInterface.get_edited_scene_root()
	var undo_redo = EditorInterface.get_editor_undo_redo()
	line_2d.name = "Stroke"
	line_2d.default_color = %ColorPickerButton.color
	line_2d.width = stroke_width_input.value
	line_2d.begin_cap_mode = _get_selected_begin_cap_mode()
	line_2d.end_cap_mode = _get_selected_end_cap_mode()
	line_2d.joint_mode = _get_selected_joint_mode()
	line_2d.sharp_limit = 90.0
	undo_redo.create_action("Add Line2D to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', line_2d, true)
	undo_redo.add_do_method(line_2d, 'set_owner', root)
	undo_redo.add_do_reference(line_2d)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'line', line_2d)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', line_2d)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'line', null)
	undo_redo.commit_action()


func _on_create_poly_stroke_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if is_instance_valid(scalable_vector_shape_2d.poly_stroke):
		return

	var poly_stroke := Polygon2D.new()
	var root := EditorInterface.get_edited_scene_root()
	var undo_redo = EditorInterface.get_editor_undo_redo()
	poly_stroke.name = "PolyStroke"
	poly_stroke.color = %ColorPickerButton.color
	#poly_stroke.width = stroke_width_input.value
	#poly_stroke.begin_cap_mode = _get_selected_begin_cap_mode()
	#poly_stroke.end_cap_mode = _get_selected_end_cap_mode()
	#poly_stroke.joint_mode = _get_selected_joint_mode()
	#poly_stroke.sharp_limit = 90.0
	undo_redo.create_action("Add Polygon2D for Stroke to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', poly_stroke, true)
	undo_redo.add_do_method(poly_stroke, 'set_owner', root)
	undo_redo.add_do_reference(poly_stroke)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'poly_stroke', poly_stroke)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', poly_stroke)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'poly_stroke', null)
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
			scalable_vector_shape_2d.line, "default_color", %ColorPickerButton.color
		)


func _on_key_frame_capabilities_changed():
	%AddStrokeColorKeyFrameButton.visible = _is_key_frame_capable()
	%AddStrokeWidthKeyFrameButton.visible = _is_key_frame_capable()


func _on_color_picker_button_toggled(toggled_on: bool) -> void:
	if not is_instance_valid(scalable_vector_shape_2d.line):
		return
	var undo_redo = EditorInterface.get_editor_undo_redo()
	if toggled_on:
		undo_redo.create_action("Adjust Line2D default_color for %s" % str(scalable_vector_shape_2d))
		undo_redo.add_undo_property(scalable_vector_shape_2d.line, 'default_color', scalable_vector_shape_2d.line.default_color)
		undo_redo.add_undo_property(%ColorPickerButton, 'color', scalable_vector_shape_2d.line.default_color)
	else:
		undo_redo.add_do_property(scalable_vector_shape_2d.line, 'default_color', %ColorPickerButton.color)
		undo_redo.add_do_property(%ColorPickerButton, 'color', %ColorPickerButton.color)
		undo_redo.commit_action(false)


func _set_cap_mode(prop_name : StringName, new_cap_mode : Line2D.LineCapMode) -> void:
	if not is_instance_valid(scalable_vector_shape_2d.line):
		return
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set Line2D %s for %s" % [prop_name, str(scalable_vector_shape_2d)])
	undo_redo.add_do_property(scalable_vector_shape_2d.line, prop_name, new_cap_mode)
	undo_redo.add_undo_property(scalable_vector_shape_2d.line, prop_name, scalable_vector_shape_2d.line.get(prop_name))
	undo_redo.commit_action()
	_on_svs_assignment_changed()


func _on_begin_no_cap_toggle_button_button_down() -> void:
	_set_cap_mode('begin_cap_mode', Line2D.LineCapMode.LINE_CAP_NONE)


func _on_begin_box_cap_toggle_button_button_down() -> void:
	_set_cap_mode('begin_cap_mode', Line2D.LineCapMode.LINE_CAP_BOX)


func _on_begin_round_cap_toggle_button_button_down() -> void:
	_set_cap_mode('begin_cap_mode', Line2D.LineCapMode.LINE_CAP_ROUND)


func _on_end_no_cap_toggle_button_button_down() -> void:
	_set_cap_mode('end_cap_mode', Line2D.LineCapMode.LINE_CAP_NONE)


func _on_end_box_cap_toggle_button_button_down() -> void:
	_set_cap_mode('end_cap_mode', Line2D.LineCapMode.LINE_CAP_BOX)


func _on_end_round_cap_toggle_button_button_down() -> void:
	_set_cap_mode('end_cap_mode', Line2D.LineCapMode.LINE_CAP_ROUND)


func _set_joint_mode(new_mode : Line2D.LineJointMode) -> void:
	if not is_instance_valid(scalable_vector_shape_2d.line):
		return
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set Line2D joint_mode for %s" % str(scalable_vector_shape_2d))
	undo_redo.add_do_property(scalable_vector_shape_2d.line, 'joint_mode', new_mode)
	undo_redo.add_undo_property(scalable_vector_shape_2d.line, 'joint_mode', scalable_vector_shape_2d.line.joint_mode)
	undo_redo.commit_action()
	_on_svs_assignment_changed()


func _on_line_joint_sharp_toggle_button_button_down() -> void:
	_set_joint_mode(Line2D.LineJointMode.LINE_JOINT_SHARP)


func _on_line_joint_bevel_toggle_button_button_down() -> void:
	_set_joint_mode(Line2D.LineJointMode.LINE_JOINT_BEVEL)


func _on_line_joint_round_toggle_button_button_down() -> void:
	_set_joint_mode(Line2D.LineJointMode.LINE_JOINT_ROUND)

