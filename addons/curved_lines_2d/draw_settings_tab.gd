@tool

extends Control


func _enter_tree() -> void:
	var granularity_input := _make_number_input(
		"Granularity",
		4, 1, 50, "px"
	)
	%Granularity.add_child(granularity_input)
	granularity_input.value_changed.connect(_on_granularity_value_changed)


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

