@tool
extends Control

var snap_resolution_input : EditorSpinSlider
var tolerance_degrees_input : EditorSpinSlider
var max_stages_input : EditorSpinSlider

func _enter_tree() -> void:
	%EnableEditingCheckbox.button_pressed = CurvedLines2D._is_editing_enabled()
	%EnableHintsCheckbox.button_pressed = CurvedLines2D._are_hints_enabled()
	%EnablePointNumbersCheckbox.button_pressed = CurvedLines2D._am_showing_point_numbers()
	%SnapToPixelCheckBox.button_pressed = CurvedLines2D._is_snapped_to_pixel()
	%UpdateCurveAtRuntimeCheckbox.button_pressed = CurvedLines2D._is_setting_update_curve_at_runtime()
	%MakeResourcesLocalToSceneCheckBox.button_pressed = CurvedLines2D._is_making_curve_resources_local_to_scene()

	snap_resolution_input = _make_number_input("Snap distance", CurvedLines2D._get_snap_resolution(), 1.0, 1024.0, "px", 1.0)
	%SnapResolutionInputContainer.add_child(snap_resolution_input)
	snap_resolution_input.value_changed.connect(_on_snap_resolution_value_changed)
	if not snap_resolution_input.focus_exited.is_connected(ProjectSettings.save):
		snap_resolution_input.focus_exited.connect(ProjectSettings.save)

	tolerance_degrees_input = _make_number_input("Tolerance Degrees", CurvedLines2D._get_default_tolerance_degrees(), 0.0, 180.0, "°", 0.5)
	%ToleranceDegreesInputContainer.add_child(tolerance_degrees_input)
	tolerance_degrees_input.value_changed.connect(_on_tolerance_degrees_input_changed)
	if not tolerance_degrees_input.focus_exited.is_connected(ProjectSettings.save):
		tolerance_degrees_input.focus_exited.connect(ProjectSettings.save)

	max_stages_input = _make_number_input("Max Stages", CurvedLines2D._get_default_max_stages(), 1, 10, "")
	%MaxStagesInputContainer.add_child(max_stages_input)
	max_stages_input.value_changed.connect(_on_max_stages_input_changed)
	if not max_stages_input.focus_exited.is_connected(ProjectSettings.save):
		max_stages_input.focus_exited.connect(ProjectSettings.save)

	%AddAntialiasedLine2DCheckbox.button_pressed = CurvedLines2D._use_antialiased_line_2d()

func _make_number_input(lbl : String, value : float, min_value : float, max_value : float, suffix : String, step := 1.0) -> EditorSpinSlider:
	var x_slider := EditorSpinSlider.new()
	x_slider.value = value
	x_slider.min_value = min_value
	x_slider.max_value = max_value
	x_slider.suffix = suffix
	x_slider.label = lbl
	x_slider.step = step
	return x_slider


func _on_enable_editing_checkbox_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_EDITING_ENABLED, toggled_on)
	ProjectSettings.save()


func _on_enable_hints_checkbox_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_HINTS_ENABLED, toggled_on)
	ProjectSettings.save()


func _on_enable_point_numbers_checkbox_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_SHOW_POINT_NUMBERS, toggled_on)
	ProjectSettings.save()


func _on_snap_to_pixel_check_box_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_SNAP_TO_PIXEL,
			toggled_on)
	ProjectSettings.save()


func _on_snap_resolution_value_changed(val : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_SNAP_RESOLUTION, val)


func _on_tolerance_degrees_input_changed(val : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_CURVE_TOLERANCE_DEGREES, val)


func _on_max_stages_input_changed(val : int) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_CURVE_MAX_STAGES, val)


func _on_update_curve_at_runtime_checkbox_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_CURVE_UPDATE_CURVE_AT_RUNTIME, toggled_on)
	ProjectSettings.save()


func _on_make_resources_local_to_scene_check_box_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_CURVE_RESOURCE_LOCAL_TO_SCENE, toggled_on)
	ProjectSettings.save()



func _on_add_antialiased_line_2d_checkbox_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ANTIALIASED_LINE_2D, toggled_on)
	ProjectSettings.save()
