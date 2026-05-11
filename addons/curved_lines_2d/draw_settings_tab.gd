@tool
extends Control

signal brush_changed()

var brush_size_x_input : EditorSpinSlider
var brush_size_y_input : EditorSpinSlider
var brush_rotation_input : EditorSpinSlider

func _enter_tree() -> void:
	var granularity_input := _make_number_input("Granularity", CurvedLines2D._get_pencil_granularity(), 1, 50, "px")
	%Granularity.add_child(granularity_input)
	granularity_input.value_changed.connect(_on_granularity_value_changed)

	brush_size_x_input = _make_number_input("Size X", CurvedLines2D._get_brush_size_x(), 1, 500, "px")
	%BrushSizeXContainer.add_child(brush_size_x_input)
	brush_size_x_input.value_changed.connect(_on_brush_size_x_value_changed)

	brush_size_y_input = _make_number_input("Size Y", CurvedLines2D._get_brush_size_y(), 1, 500, "px")
	%BrushSizeYContainer.add_child(brush_size_y_input)
	brush_size_y_input.value_changed.connect(_on_brush_size_y_value_changed)

	brush_rotation_input = _make_number_input("Rotation", CurvedLines2D._get_brush_rotation(), 0, 360, "°")
	%BrushRotationContainer.add_child(brush_rotation_input)
	brush_rotation_input.value_changed.connect(_on_brush_rotation_value_changed)

	%KeepDrawingOptionButton.select(CurvedLines2D._get_keep_drawing_behavior())
	%ClosePathCheckBox.button_pressed = CurvedLines2D._get_close_pencil_path()
	%BrushShapeOptionButton.select(CurvedLines2D._get_brush_shape())

func sync_settings() -> void:
	brush_size_x_input.set_value_no_signal(CurvedLines2D._get_brush_size_x())
	brush_size_y_input.set_value_no_signal(CurvedLines2D._get_brush_size_y())
	brush_rotation_input.set_value_no_signal(CurvedLines2D._get_brush_rotation())
	%BrushShapeOptionButton.select(CurvedLines2D._get_brush_shape())
	ProjectSettings.save()


func _on_granularity_value_changed(new_val) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PENCIL_GRANULARITY, new_val)
	ProjectSettings.save()


func _on_brush_size_x_value_changed(new_val) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_BRUSH_SIZE_X, new_val)
	ProjectSettings.save()
	brush_changed.emit()


func _on_brush_size_y_value_changed(new_val) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_BRUSH_SIZE_Y, new_val)
	ProjectSettings.save()
	brush_changed.emit()


func _on_brush_rotation_value_changed(new_val) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_BRUSH_ROTATION, new_val)
	ProjectSettings.save()
	brush_changed.emit()


func _make_number_input(lbl : String, value : float, min_value : float, max_value : float, suffix : String, step := 1.0) -> EditorSpinSlider:
	var x_slider := EditorSpinSlider.new()
	x_slider.value = value
	x_slider.min_value = min_value
	x_slider.max_value = max_value
	x_slider.suffix = suffix
	x_slider.label = lbl
	x_slider.step = step
	return x_slider


func _on_keep_drawing_option_button_item_selected(opt : CurvedLines2D.KeepDrawingBehavior) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_KEEP_DRAWING, opt)
	ProjectSettings.save()


func _on_close_path_check_box_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_CLOSE_PENCIL_PATH, toggled_on)
	ProjectSettings.save()


func _on_brush_shape_option_button_item_selected(opt: int) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_BRUSH_SHAPE, opt)
	ProjectSettings.save()
	brush_changed.emit()
