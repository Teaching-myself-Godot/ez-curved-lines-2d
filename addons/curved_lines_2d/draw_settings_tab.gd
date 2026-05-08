@tool

extends Control


func _enter_tree() -> void:
	var granularity_input := _make_number_input(
		"Granularity",
		CurvedLines2D._get_pencil_granularity(), 1, 50, "px"
	)
	%Granularity.add_child(granularity_input)
	granularity_input.value_changed.connect(_on_granularity_value_changed)
	%KeepDrawingOptionButton.select(CurvedLines2D._get_keep_drawing_behavior())
	%ClosePathCheckBox.button_pressed = CurvedLines2D._get_close_pencil_path()


func _on_granularity_value_changed(new_val) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PENCIL_GRANULARITY, new_val)
	ProjectSettings.save()


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
