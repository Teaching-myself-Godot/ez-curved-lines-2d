@tool
extends Control

signal shape_created(curve : Curve2D, scene_root : Node2D, node_name : String)
signal rect_created(width : float, height : float, rx : float, ry : float, scene_root : Node2D)
signal ellipse_created(rx : float, ry : float, scene_root : Node2D)
signal set_shape_preview(curve : Curve2D)

signal mode_changed(new_mode : CurvedLines2D.SVSEditMode)
signal flip_horizontal()
signal flip_vertical()

var snap_resolution_input : EditorSpinSlider
var stroke_width_input : EditorSpinSlider

@onready var mode_containers := [
	%CreateEllipseContainer, %PlaceHolderContainer
]


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

	# Pixel Snap Settings
	%SnapButton.button_pressed = CurvedLines2D._is_snapped_to_pixel()
	snap_resolution_input = _make_number_input("Snap", CurvedLines2D._get_snap_resolution(), 1.0, 1024.0, "px", 1.0)
	%SnapResolutionInputContainer.add_child(snap_resolution_input)
	snap_resolution_input.value_changed.connect(_on_snap_resolution_value_changed)
	if not snap_resolution_input.focus_exited.is_connected(ProjectSettings.save):
		snap_resolution_input.focus_exited.connect(ProjectSettings.save)

	# Fill and Stroke Settings
	%StrokePickerButton.color = CurvedLines2D._get_default_stroke_color()
	if not %StrokePickerButton.focus_exited.is_connected(ProjectSettings.save):
		%StrokePickerButton.focus_exited.connect(ProjectSettings.save)
	%FillPickerButton.color = CurvedLines2D._get_default_fill_color()
	if not %FillPickerButton.focus_exited.is_connected(ProjectSettings.save):
		%FillPickerButton.focus_exited.connect(ProjectSettings.save)
	%EnableStrokeCheckBox.button_pressed = CurvedLines2D._is_add_stroke_enabled()
	%EnableFillCheckBox.button_pressed = CurvedLines2D._is_add_fill_enabled()
	stroke_width_input = _make_number_input("Size", 10.0, 0.5, 100.0, "px", 0.5)
	stroke_width_input.value = CurvedLines2D._get_default_stroke_width()
	stroke_width_input.value_changed.connect(_on_stroke_width_input_value_changed)
	%StrokeWidthContainer.add_child(stroke_width_input)


	# Collision Object
	(%CollisionObjectTypeOptionButton as OptionButton).select(CurvedLines2D._add_collision_object_type())


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
	for mode_container : Control in mode_containers:
		mode_container.hide()
	match mode:
		CurvedLines2D.SVSEditMode.CREATE_ELLIPSE:
			%CreateEllipseContainer.show()
		_:
			%PlaceHolderContainer.show()
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


func sync_settings() -> void:
	push_warning("TODO: synchronize brush settings")
	#brush_size_x_input.set_value_no_signal(CurvedLines2D._get_brush_size_x())
	#brush_size_y_input.set_value_no_signal(CurvedLines2D._get_brush_size_y())
	#brush_rotation_input.set_value_no_signal(CurvedLines2D._get_brush_rotation())
	#%BrushShapeOptionButton.select(CurvedLines2D._get_brush_shape())
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


func _on_snap_resolution_value_changed(val : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_SNAP_RESOLUTION, val)


func _on_snap_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_SNAP_TO_PIXEL, toggled_on)
	ProjectSettings.save()


func _on_fill_picker_button_color_changed(color: Color) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_FILL_COLOR, color)


func _on_stroke_picker_button_color_changed(color: Color) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_STROKE_COLOR, color)


func _on_stroke_check_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_STROKE_ENABLED, toggled_on)
	ProjectSettings.save()


func _on_stroke_width_input_value_changed(new_value: float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_STROKE_WIDTH, new_value)


func _on_fill_check_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_FILL_ENABLED, toggled_on)
	ProjectSettings.save()


func _on_collision_object_type_option_button_type_selected(obj_type: ScalableVectorShape2D.CollisionObjectType) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_COLLISION_TYPE, obj_type)
