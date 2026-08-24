@tool
extends Control

signal shape_created(curve : Curve2D, scene_root : Node2D, node_name : String)
signal rect_created(width : float, height : float, rx : float, ry : float, scene_root : Node2D)
signal ellipse_created(rx : float, ry : float, scene_root : Node2D)
signal set_shape_preview(curve : Curve2D)

const OPEN_SCENE_ERROR_MESSAGE := "Can only create a shape in an open scene"

var stroke_width_input : EditorSpinSlider

var rect_width_input : EditorSpinSlider
var rect_height_input : EditorSpinSlider
var rect_rx_input : EditorSpinSlider
var rect_ry_input : EditorSpinSlider

var ellipse_rx_input : EditorSpinSlider
var ellipse_ry_input : EditorSpinSlider

var warning_dialog : AcceptDialog = null

var begin_cap_button_map = {}
var end_cap_button_map = {}
var joint_button_map = {}

func _enter_tree() -> void:
	rect_width_input = _make_number_input("Width", 100, 2, 1000, "")
	rect_height_input = _make_number_input("Height", 100, 2, 1000, "")
	rect_rx_input = _make_number_input("Corner Radius X", 0, 0, 500, "")
	rect_ry_input = _make_number_input("Corner Radius Y", 0, 0, 500, "")

	stroke_width_input = _make_number_input("Width", 10.0, 0.5, 100.0, "px", 0.5)
	%WidthSliderContainer.add_child(rect_width_input)
	%HeightSliderContainer.add_child(rect_height_input)
	%XRadiusSliderContainer.add_child(rect_rx_input)
	%YRadiusSliderContainer.add_child(rect_ry_input)
	%StrokeWidthContainer.add_child(stroke_width_input)
	ellipse_rx_input = _make_number_input("Horizontal Radius (RX)", 50, 1, 500, "")
	ellipse_ry_input = _make_number_input("Vertical Radius (RY)", 50, 1, 500, "")
	%EllipseXRadiusSliderContainer.add_child(ellipse_rx_input)
	%EllipseYRadiusSliderContainer.add_child(ellipse_ry_input)
	stroke_width_input.value = CurvedLines2D._get_default_stroke_width()
	stroke_width_input.value_changed.connect(_on_stroke_width_input_value_changed)
	%StrokePickerButton.color = CurvedLines2D._get_default_stroke_color()
	%UseLine2DCheckButton.button_pressed = CurvedLines2D._using_line_2d_for_stroke()
	%FillPickerButton.color = CurvedLines2D._get_default_fill_color()
	%StrokeCheckButton.button_pressed = CurvedLines2D._is_add_stroke_enabled()
	%FillCheckButton.button_pressed = CurvedLines2D._is_add_fill_enabled()
	(%CollisionObjectTypeOptionButton as OptionButton).select(CurvedLines2D._add_collision_object_type())

	begin_cap_button_map[Line2D.LineCapMode.LINE_CAP_NONE] = %BeginNoCapToggleButton
	begin_cap_button_map[Line2D.LineCapMode.LINE_CAP_BOX] = %BeginBoxCapToggleButton
	begin_cap_button_map[Line2D.LineCapMode.LINE_CAP_ROUND] = %BeginRoundCapToggleButton
	end_cap_button_map[Line2D.LineCapMode.LINE_CAP_NONE] = %EndNoCapToggleButton
	end_cap_button_map[Line2D.LineCapMode.LINE_CAP_BOX] = %EndBoxCapToggleButton
	end_cap_button_map[Line2D.LineCapMode.LINE_CAP_ROUND] = %EndRoundCapToggleButton
	joint_button_map[Line2D.LineJointMode.LINE_JOINT_SHARP] = %LineJointSharpToggleButton
	joint_button_map[Line2D.LineJointMode.LINE_JOINT_BEVEL] = %LineJointBevelToggleButton
	joint_button_map[Line2D.LineJointMode.LINE_JOINT_ROUND] = %LineJointRoundToggleButton
	begin_cap_button_map[CurvedLines2D._get_default_begin_cap()].button_pressed = true
	end_cap_button_map[CurvedLines2D._get_default_end_cap()].button_pressed = true
	joint_button_map[CurvedLines2D._get_default_joint_mode()].button_pressed = true


	if not stroke_width_input.value_focus_exited.is_connected(ProjectSettings.save):
		stroke_width_input.value_focus_exited.connect(ProjectSettings.save)
	if not %StrokePickerButton.focus_exited.is_connected(ProjectSettings.save):
		%StrokePickerButton.focus_exited.connect(ProjectSettings.save)
	if not %FillPickerButton.focus_exited.is_connected(ProjectSettings.save):
		%FillPickerButton.focus_exited.connect(ProjectSettings.save)

	find_children("PaintOrderButton*")[CurvedLines2D._get_default_paint_order()].button_pressed = true


func _make_number_input(lbl : String, value : float, min_value : float, max_value : float, suffix : String, step := 1.0) -> EditorSpinSlider:
	var x_slider := EditorSpinSlider.new()
	x_slider.value = value
	x_slider.min_value = min_value
	x_slider.max_value = max_value
	x_slider.suffix = suffix
	x_slider.label = lbl
	x_slider.step = step
	return x_slider


func _get_rect_curve() -> Curve2D:
	var curve := Curve2D.new()
	ScalableVectorShape2D.set_rect_points(curve, rect_width_input.value, rect_height_input.value, rect_rx_input.value, rect_ry_input.value)
	return curve


func _on_create_rect_as_path_button_pressed() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root is Node:
		warning_dialog.dialog_text = OPEN_SCENE_ERROR_MESSAGE
		warning_dialog.popup_centered()
		return
	shape_created.emit(_get_rect_curve(), scene_root, "Rectangle")


func _on_create_rect_button_pressed() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root is Node:
		warning_dialog.dialog_text = OPEN_SCENE_ERROR_MESSAGE
		warning_dialog.popup_centered()
		return
	rect_created.emit(rect_width_input.value, rect_height_input.value,
		rect_rx_input.value, rect_ry_input.value, scene_root)


func _on_create_ellipse_button_pressed() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root is Node:
		warning_dialog.dialog_text = OPEN_SCENE_ERROR_MESSAGE
		warning_dialog.popup_centered()
		return
	ellipse_created.emit(ellipse_rx_input.value, ellipse_ry_input.value, scene_root)


func _get_ellipse_curve() -> Curve2D:
	var curve := Curve2D.new()
	ScalableVectorShape2D.set_ellipse_points(curve, Vector2(ellipse_rx_input.value * 2, ellipse_ry_input.value * 2))
	return curve


func _on_create_rect_button_mouse_entered() -> void:
	set_shape_preview.emit(_get_rect_curve())


func _on_create_rect_button_mouse_exited() -> void:
	set_shape_preview.emit(null)


func _on_create_circle_button_pressed() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()

	if not scene_root is Node:
		warning_dialog.dialog_text = OPEN_SCENE_ERROR_MESSAGE
		warning_dialog.popup_centered()
		return

	var node_name := "Circle" if ellipse_rx_input.value == ellipse_ry_input.value else "Ellipse"
	shape_created.emit(_get_ellipse_curve(), scene_root, node_name)


func _on_create_circle_button_mouse_entered() -> void:
	set_shape_preview.emit(_get_ellipse_curve())


func _on_create_circle_button_mouse_exited() -> void:
	set_shape_preview.emit(null)


func _on_create_empty_shape_button_pressed() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()

	if not scene_root is Node:
		warning_dialog.dialog_text = OPEN_SCENE_ERROR_MESSAGE
		warning_dialog.popup_centered()
		return
	var curve := Curve2D.new()
	var node_name := "Path"
	shape_created.emit(curve, scene_root, node_name)


func _on_stroke_width_input_value_changed(new_value: float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_STROKE_WIDTH, new_value)


func _on_fill_picker_button_color_changed(color: Color) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_FILL_COLOR, color)


func _on_stroke_picker_button_color_changed(color: Color) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_STROKE_COLOR, color)


func _on_stroke_check_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_STROKE_ENABLED, toggled_on)
	ProjectSettings.save()


func _on_fill_check_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_FILL_ENABLED, toggled_on)
	ProjectSettings.save()


func _on_paint_order_button_0_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.FILL_STROKE_MARKERS)
	ProjectSettings.save()


func _on_paint_order_button_1_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.STROKE_FILL_MARKERS)
	ProjectSettings.save()


func _on_paint_order_button_2_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.FILL_MARKERS_STROKE)
	ProjectSettings.save()


func _on_paint_order_button_3_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.MARKERS_FILL_STROKE)
	ProjectSettings.save()


func _on_paint_order_button_4_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.STROKE_MARKERS_FILL)
	ProjectSettings.save()


func _on_paint_order_button_5_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.MARKERS_STROKE_FILL)
	ProjectSettings.save()


func _on_begin_no_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_BEGIN_CAP,
			Line2D.LineCapMode.LINE_CAP_NONE)
	ProjectSettings.save()


func _on_begin_box_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_BEGIN_CAP,
			Line2D.LineCapMode.LINE_CAP_BOX)
	ProjectSettings.save()


func _on_begin_round_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_BEGIN_CAP,
			Line2D.LineCapMode.LINE_CAP_ROUND)
	ProjectSettings.save()


func _on_end_no_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_END_CAP,
			Line2D.LineCapMode.LINE_CAP_NONE)
	ProjectSettings.save()


func _on_end_box_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_END_CAP,
			Line2D.LineCapMode.LINE_CAP_BOX)
	ProjectSettings.save()


func _on_end_round_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_END_CAP,
			Line2D.LineCapMode.LINE_CAP_ROUND)
	ProjectSettings.save()


func _on_line_joint_sharp_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_JOINT_MODE,
			Line2D.LineJointMode.LINE_JOINT_SHARP)
	ProjectSettings.save()


func _on_line_joint_bevel_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_JOINT_MODE,
			Line2D.LineJointMode.LINE_JOINT_BEVEL)
	ProjectSettings.save()


func _on_line_joint_round_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_JOINT_MODE,
			Line2D.LineJointMode.LINE_JOINT_ROUND)
	ProjectSettings.save()


func _on_collision_object_type_option_button_type_selected(obj_type: ScalableVectorShape2D.CollisionObjectType) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_COLLISION_TYPE, obj_type)


func _on_use_line_2d_check_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_USE_LINE_2D_FOR_STROKE, toggled_on)
	if toggled_on:
		%EndCapForm.show()
	else:
		%EndCapForm.hide()
