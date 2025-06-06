@tool
extends Control

class_name ScalableVectorShapeEditTab

signal shape_created(curve : Curve2D, scene_root : Node2D, node_name : String)
signal rect_created(width : float, height : float, rx : float, ry : float, scene_root : Node2D)
signal ellipse_created(rx : float, ry : float, scene_root : Node2D)
signal set_shape_preview(curve : Curve2D)

var stroke_width_input : EditorSpinSlider
var stroke_color_button : ColorPickerButton
var fill_color_button : ColorPickerButton

var rect_width_input : EditorSpinSlider
var rect_height_input : EditorSpinSlider
var rect_rx_input : EditorSpinSlider
var rect_ry_input : EditorSpinSlider

var ellipse_rx_input : EditorSpinSlider
var ellipse_ry_input : EditorSpinSlider

var warning_dialog : AcceptDialog = null

func _enter_tree() -> void:
	rect_width_input = _make_number_input("Width", 100, 2, 1000, "")
	rect_height_input = _make_number_input("Height", 100, 2, 1000, "")
	rect_rx_input = _make_number_input("Corner Radius X", 0, 0, 500, "")
	rect_ry_input = _make_number_input("Corner Radius Y", 0, 0, 500, "")
	stroke_color_button = find_child("StrokePickerButton")
	fill_color_button = find_child("FillPickerButton")
	stroke_width_input = _make_number_input("Stroke Width", 10.0, 0.0, 100.0, "", 0.01)
	find_child("WidthSliderContainer").add_child(rect_width_input)
	find_child("HeightSliderContainer").add_child(rect_height_input)
	find_child("XRadiusSliderContainer").add_child(rect_rx_input)
	find_child("YRadiusSliderContainer").add_child(rect_ry_input)
	find_child("StrokeWidthContainer").add_child(stroke_width_input)
	ellipse_rx_input = _make_number_input("Horizontal Radius (RX)", 50, 1, 500, "")
	ellipse_ry_input = _make_number_input("Vertical Radius (RY)", 50, 1, 500, "")
	find_child("EllipseXRadiusSliderContainer").add_child(ellipse_rx_input)
	find_child("EllipseYRadiusSliderContainer").add_child(ellipse_ry_input)
	find_child("EnableEditingCheckbox").button_pressed = CurvedLines2D._is_editing_enabled()
	find_child("EnableHintsCheckbox").button_pressed = CurvedLines2D._are_hints_enabled()
	find_child("EnablePointNumbersCheckbox").button_pressed = CurvedLines2D._am_showing_point_numbers()
	stroke_width_input.value = CurvedLines2D._get_default_stroke_width()
	stroke_width_input.value_changed.connect(_on_stroke_width_input_value_changed)
	stroke_color_button.color = CurvedLines2D._get_default_stroke_color()
	fill_color_button.color = CurvedLines2D._get_default_fill_color()
	find_child("StrokeCheckButton").button_pressed = CurvedLines2D._is_add_stroke_enabled()
	find_child("FillCheckButton").button_pressed = CurvedLines2D._is_add_fill_enabled()
	find_child("CollisionCheckButton").button_pressed = CurvedLines2D._is_add_collision_enabled()
	if not stroke_width_input.value_focus_exited.is_connected(ProjectSettings.save):
		stroke_width_input.value_focus_exited.connect(ProjectSettings.save)
	if not stroke_color_button.focus_exited.is_connected(ProjectSettings.save):
		stroke_color_button.focus_exited.connect(ProjectSettings.save)
	if not fill_color_button.focus_exited.is_connected(ProjectSettings.save):
		fill_color_button.focus_exited.connect(ProjectSettings.save)
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
	if not is_instance_valid(scene_root):
		warning_dialog.dialog_text = "Can only create a shape in an open 2D scene"
		warning_dialog.popup_centered()
		return

	if not scene_root is Node2D:
		warning_dialog.dialog_text = "Can only create a shape in an open 2D scene"
		warning_dialog.popup_centered()
		return
	shape_created.emit(_get_rect_curve(), scene_root, "Rectangle")


func _on_create_rect_button_pressed() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not is_instance_valid(scene_root):
		warning_dialog.dialog_text = "Can only create a shape in an open 2D scene"
		warning_dialog.popup_centered()
		return

	if not scene_root is Node2D:
		warning_dialog.dialog_text = "Can only create a shape in an open 2D scene"
		warning_dialog.popup_centered()
		return
	rect_created.emit(rect_width_input.value, rect_height_input.value,
		rect_rx_input.value, rect_ry_input.value, scene_root)


func _on_create_ellipse_button_pressed() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not is_instance_valid(scene_root):
		warning_dialog.dialog_text = "Can only create a shape in an open 2D scene"
		warning_dialog.popup_centered()
		return

	if not scene_root is Node2D:
		warning_dialog.dialog_text = "Can only create a shape in an open 2D scene"
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
	if not is_instance_valid(scene_root):
		warning_dialog.dialog_text = "Can only create a Shape in an open 2D scene"
		return
	if not scene_root is Node2D:
		warning_dialog.dialog_text = "Can only create a Shape in an open 2D scene"
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
	if not is_instance_valid(scene_root):
		warning_dialog.dialog_text = "Can only create a Shape in an open 2D scene"
		return
	if not scene_root is Node2D:
		warning_dialog.dialog_text = "Can only create a Shape in an open 2D scene"
		warning_dialog.popup_centered()
		return
	var curve := Curve2D.new()
	var node_name := "Path"
	shape_created.emit(curve, scene_root, node_name)


func _on_enable_editing_checkbox_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_EDITING_ENABLED, toggled_on)
	ProjectSettings.save()


func _on_enable_hints_checkbox_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_HINTS_ENABLED, toggled_on)
	ProjectSettings.save()


func _on_enable_point_numbers_checkbox_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_SHOW_POINT_NUMBERS, toggled_on)
	ProjectSettings.save()


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


func _on_collision_check_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_COLLISION_ENABLED, toggled_on)
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

