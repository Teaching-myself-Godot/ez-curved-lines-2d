@tool
extends Control

signal mode_changed(new_mode : CurvedLines2D.SVSEditMode)
signal flip_horizontal()
signal flip_vertical()

var snap_resolution_input : EditorSpinSlider


func _ready() -> void:
	%CircleButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.CREATE_ELLIPSE))
	%RectangleButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.CREATE_RECT))
	%EditButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.NONE))
	%TranslateButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.TRANSLATE))
	%ResizeButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.SCALE))
	%RotateButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.ROTATE))
	%BrushButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.BRUSH))
	%PencilButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.PENCIL))
	%KnifeButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.KNIFE))
	%BonePaintButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.PAINT_BONE))
	%MergeButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.MERGE))
	%FlipHorizontalButton.pressed.connect(flip_horizontal.emit)
	%FlipVerticalButton.pressed.connect(flip_vertical.emit)

	%SnapButton.button_pressed = CurvedLines2D._is_snapped_to_pixel()
	snap_resolution_input = _make_number_input("Snap", CurvedLines2D._get_snap_resolution(), 1.0, 1024.0, "px", 1.0)
	%SnapResolutionInputContainer.add_child(snap_resolution_input)
	snap_resolution_input.value_changed.connect(_on_snap_resolution_value_changed)
	if not snap_resolution_input.focus_exited.is_connected(ProjectSettings.save):
		snap_resolution_input.focus_exited.connect(ProjectSettings.save)


func _on_mode_toggled(toggled_on : bool, mode : CurvedLines2D.SVSEditMode) -> void:
	if toggled_on:
		mode_changed.emit(mode)
		show_details_for_current_mode(mode)


func set_edit_mode_toggle_button(mode : CurvedLines2D.SVSEditMode) -> void:
	match mode:
		CurvedLines2D.SVSEditMode.CREATE_ELLIPSE:
			if not %CircleButton.button_pressed:
				%CircleButton.button_pressed = true
		CurvedLines2D.SVSEditMode.CREATE_RECT:
			if not %RectangleButton.button_pressed:
				%RectangleButton.button_pressed = true
		CurvedLines2D.SVSEditMode.NONE:
			if not %EditButton.button_pressed:
				%EditButton.button_pressed = true
		CurvedLines2D.SVSEditMode.TRANSLATE:
			if not %TranslateButton.button_pressed:
				%TranslateButton.button_pressed = true
		CurvedLines2D.SVSEditMode.SCALE:
			if not %ResizeButton.button_pressed:
				%ResizeButton.button_pressed = true
		CurvedLines2D.SVSEditMode.ROTATE:
			if not %RotateButton.button_pressed:
				%RotateButton.button_pressed = true
		CurvedLines2D.SVSEditMode.BRUSH:
			if not %BrushButton.button_pressed:
				%BrushButton.button_pressed = true
		CurvedLines2D.SVSEditMode.PENCIL:
			if not %PencilButton.button_pressed:
				%PencilButton.button_pressed = true
		CurvedLines2D.SVSEditMode.KNIFE:
			if not %KnifeButton.button_pressed:
				%KnifeButton.button_pressed = true
		CurvedLines2D.SVSEditMode.PAINT_BONE:
			if not %BonePaintButton.button_pressed:
				%BonePaintButton.button_pressed = true
		CurvedLines2D.SVSEditMode.MERGE:
			if not %MergeButton.button_pressed:
				%MergeButton.button_pressed = true
		_:
			if not %EditButton.button_pressed:
				%EditButton.button_pressed = true


func show_details_for_current_mode(mode : CurvedLines2D.SVSEditMode) -> void:
	push_warning("TODO: show current details for: ", mode)


func enable_svs_editors() -> void:
	%RotateButton.disabled = false
	%TranslateButton.disabled = false
	%ResizeButton.disabled = false
	%FlipHorizontalButton.disabled = false
	%FlipVerticalButton.disabled = false
	%BonePaintButton.disabled = false
	%EditButton.disabled = false
	%KnifeButton.disabled = false
	%BrushButton.disabled = false
	%MergeButton.disabled = false
	%PencilButton.disabled = false


func set_default_mode() -> void:
	%EditButton.button_pressed = true


func disable_svs_editors(disable_all := false) -> void:
	%RotateButton.disabled = true
	%TranslateButton.disabled = true
	%ResizeButton.disabled = true
	%FlipHorizontalButton.disabled = true
	%FlipVerticalButton.disabled = true
	%BonePaintButton.disabled = true
	%EditButton.disabled = true
	%KnifeButton.disabled = true
	%BrushButton.disabled = disable_all
	%MergeButton.disabled = disable_all
	%PencilButton.disabled = disable_all


func disable_all_editors() -> void:
	disable_svs_editors(true)


func _make_number_input(lbl : String, value : float, min_value : float, max_value : float, suffix : String, step := 1.0) -> EditorSpinSlider:
	var x_slider := EditorSpinSlider.new()
	x_slider.value = value
	x_slider.min_value = min_value
	x_slider.max_value = max_value
	x_slider.suffix = suffix
	x_slider.label = lbl
	x_slider.step = step
	return x_slider


func _on_snap_resolution_value_changed(val : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_SNAP_RESOLUTION, val)


func _on_snap_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_SNAP_TO_PIXEL, toggled_on)
	ProjectSettings.save()
