@tool
extends Control

signal shape_created(curve : Curve2D, scene_root : Node2D, node_name : String)
signal rect_created(width : float, height : float, rx : float, ry : float, scene_root : Node2D)
signal ellipse_created(rx : float, ry : float, scene_root : Node2D)
signal set_shape_preview(curve : Curve2D)

signal mode_changed(new_mode : CurvedLines2D.SVSEditMode)
signal flip_horizontal()
signal flip_vertical()
signal brush_changed()

const OPEN_SCENE_ERROR_MESSAGE := "Can only create a shape in an open scene"

var stroke_width_input : EditorSpinSlider

var rect_width_input : EditorSpinSlider
var rect_height_input : EditorSpinSlider
var rect_rx_input : EditorSpinSlider
var rect_ry_input : EditorSpinSlider

var ellipse_rx_input : EditorSpinSlider
var ellipse_ry_input : EditorSpinSlider

var pencil_granularity_input : EditorSpinSlider
var brush_granularity_input : EditorSpinSlider
var brush_size_x_input : EditorSpinSlider
var brush_size_y_input : EditorSpinSlider
var brush_rotation_input : EditorSpinSlider

var warning_dialog : AcceptDialog = null

var tab_default_min_height : int


var granularity_inputs : Array[EditorSpinSlider] = []

@onready var mode_containers : Array[Container] = [
	%CreateEllipseContainer, %CreateRectContainer,
	%SelectModeContainer, %PencilToolContainer,
	%BrushToolContainer
]

@onready var tool_mode_button_group : ButtonGroup =	%CircleButton.button_group

@onready var keep_drawing_checkboxes : Array[CheckBox] = [
	%MakeAnotherEllipseCheckBox,
	%MakeAnotherRectCheckBox,
	%KeepPencilDrawingCheckBox,
	%KeepBrushingCheckBox
]

@onready var fit_curve_check_boxes : Array[CheckBox] = [
	%FitCurveToPencilCheckBox, %FitCurveToBrushStrokeCheckBox
]

var _changing_color := false

func _ready() -> void:
	_hide_mode_containers()
	%SelectModeContainer.show()
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

	# Fill and Stroke Settings
	%StrokePickerButton.color = CurvedLines2D._get_default_stroke_color()
	if not %StrokePickerButton.popup_closed.is_connected(_on_stroke_picker_button_popup_closed):
		%StrokePickerButton.popup_closed.connect(_on_stroke_picker_button_popup_closed)
	%FillPickerButton.color = CurvedLines2D._get_default_fill_color()
	if not %FillPickerButton.popup_closed.is_connected(_on_fill_picker_button_popup_closed):
		%FillPickerButton.popup_closed.connect(_on_fill_picker_button_popup_closed)
	%EnableStrokeCheckBox.button_pressed = CurvedLines2D._is_add_stroke_enabled()
	%EnableFillCheckBox.button_pressed = CurvedLines2D._is_add_fill_enabled()
	stroke_width_input = _make_number_input("Thickness", 10.0, 0.5, 100.0, "px", 0.5)
	stroke_width_input.value = CurvedLines2D._get_default_stroke_width()
	stroke_width_input.value_changed.connect(_on_stroke_width_input_value_changed)
	%StrokeWidthContainer.add_child(stroke_width_input)

	%CollisionObjectTypeOptionButton.select(CurvedLines2D._add_collision_object_type())
	%BeginBoxCapToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_begin_cap() == Line2D.LINE_CAP_BOX)
	%BeginNoCapToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_begin_cap() ==  Line2D.LINE_CAP_NONE)
	%BeginRoundCapToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_begin_cap() ==  Line2D.LINE_CAP_ROUND)
	%EndBoxCapToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_end_cap() ==  Line2D.LINE_CAP_BOX)
	%EndNoCapToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_end_cap() == Line2D.LINE_CAP_NONE)
	%EndRoundCapToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_end_cap() == Line2D.LINE_CAP_ROUND)
	%LineJoinSharpToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_joint_mode() == Line2D.LINE_JOINT_SHARP)
	%LineJointRoundToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_joint_mode() == Line2D.LINE_JOINT_ROUND)
	%LineJointBevelToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_joint_mode() == Line2D.LINE_JOINT_BEVEL)
	%MiddleToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_stroke_extrusion_direction() == ScalableVectorShape2D.StrokeExtrusionDirection.MIDDLE)
	%InsideToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_stroke_extrusion_direction() == ScalableVectorShape2D.StrokeExtrusionDirection.INWARD)
	%OutsideToggleButton.set_pressed_no_signal(CurvedLines2D._get_default_stroke_extrusion_direction() == ScalableVectorShape2D.StrokeExtrusionDirection.OUTWARD)


	if (CurvedLines2D._get_keep_drawing_behavior() ==
				CurvedLines2D.KeepDrawingBehavior.KEEP_DRAWING_ON_SAME_PARENT):
		for b : CheckBox in keep_drawing_checkboxes:
			b.set_pressed_no_signal(true)
	else:
		for b : CheckBox in keep_drawing_checkboxes:
			b.set_pressed_no_signal(false)

	# Collision Object
	(%CollisionObjectTypeOptionButton as OptionButton).select(CurvedLines2D._add_collision_object_type())

	# Create Ellipse Settings
	ellipse_rx_input = _make_number_input("Horizontal Radius (RX)", 50, 1, 500, "")
	ellipse_rx_input.value = CurvedLines2D._get_default_ellipse_rx()
	ellipse_rx_input.value_changed.connect(_on_ellipse_rx_value_changed)
	ellipse_ry_input = _make_number_input("Vertical Radius (RY)", 50, 1, 500, "")
	ellipse_ry_input.value = CurvedLines2D._get_default_ellipse_ry()
	ellipse_ry_input.value_changed.connect(_on_ellipse_ry_value_changed)
	%EllipseXRadiusSliderContainer.add_child(ellipse_rx_input)
	%EllipseYRadiusSliderContainer.add_child(ellipse_ry_input)

	# Create Rectangle Settings
	rect_width_input = _make_number_input("Width", 100, 2, 1000, "")
	rect_width_input.value = CurvedLines2D._get_default_rect_width()
	rect_width_input.value_changed.connect(_on_rect_width_value_changed)
	rect_height_input = _make_number_input("Height", 100, 2, 1000, "")
	rect_height_input.value = CurvedLines2D._get_default_rect_height()
	rect_height_input.value_changed.connect(_on_rect_height_value_changed)
	rect_rx_input = _make_number_input("Corner Radius X", 0, 0, 500, "")
	rect_rx_input.value = CurvedLines2D._get_default_rect_rx()
	rect_rx_input.value_changed.connect(_on_rect_rx_value_changed)
	rect_ry_input = _make_number_input("Corner Radius Y", 0, 0, 500, "")
	rect_ry_input.value = CurvedLines2D._get_default_rect_ry()
	rect_ry_input.value_changed.connect(_on_rect_ry_value_changed)
	%WidthSliderContainer.add_child(rect_width_input)
	%HeightSliderContainer.add_child(rect_height_input)
	%XRadiusSliderContainer.add_child(rect_rx_input)
	%YRadiusSliderContainer.add_child(rect_ry_input)

	# Pencil Tool
	%ClosePathCheckBox.button_pressed = CurvedLines2D._get_close_pencil_path()
	pencil_granularity_input = _make_number_input("Granularity", CurvedLines2D._get_freehand_draw_granularity(),
			1, 50, "px", 1.0, "The minimum distance between points")
	%PencilGranularity.add_child(pencil_granularity_input)
	pencil_granularity_input.value_changed.connect(_on_granularity_value_changed)
	brush_granularity_input = _make_number_input("Granularity", CurvedLines2D._get_freehand_draw_granularity(),
			1, 50, "px", 1.0, "The minimum distance between points")
	%FitCurveToPencilCheckBox.button_pressed = CurvedLines2D._apply_curve_fitting()

	# Brush Tool
	%BrushGranularity.add_child(brush_granularity_input)
	brush_granularity_input.value_changed.connect(_on_granularity_value_changed)
	granularity_inputs.append_array([pencil_granularity_input, brush_granularity_input])
	%FitCurveToBrushStrokeCheckBox.button_pressed = CurvedLines2D._apply_curve_fitting()
	brush_size_x_input = _make_number_input("Size X", CurvedLines2D._get_brush_size_x(), 1, 500, "px")
	%BrushSizeXContainer.add_child(brush_size_x_input)
	brush_size_x_input.value_changed.connect(_on_brush_size_x_value_changed)

	brush_size_y_input = _make_number_input("Size Y", CurvedLines2D._get_brush_size_y(), 1, 500, "px")
	%BrushSizeYContainer.add_child(brush_size_y_input)
	brush_size_y_input.value_changed.connect(_on_brush_size_y_value_changed)

	brush_rotation_input = _make_number_input("Rotation", CurvedLines2D._get_brush_rotation(), 0, 360, "°")
	%BrushRotationContainer.add_child(brush_rotation_input)
	brush_rotation_input.value_changed.connect(_on_brush_rotation_value_changed)
	%BrushShapeOptionButton.select(CurvedLines2D._get_brush_shape())
	%FillInParentCheckBox.button_pressed = CurvedLines2D._get_brush_fill_in_parent_shape()

	# Interface Sizing
	tab_default_min_height = custom_minimum_size.y
	_calibrate_ui_scale()



func _on_mode_toggled(toggled_on : bool, mode : CurvedLines2D.SVSEditMode) -> void:
	if toggled_on:
		mode_changed.emit(mode)
		show_details_for_current_mode(mode)
	if not tool_mode_button_group.get_pressed_button():
		mode_changed.emit(CurvedLines2D.SVSEditMode.NONE)


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


func _hide_mode_containers() -> void:
	for mode_container : Control in mode_containers:
		mode_container.hide()


func show_details_for_current_mode(mode : CurvedLines2D.SVSEditMode) -> void:
	_hide_mode_containers()
	match mode:
		CurvedLines2D.SVSEditMode.CREATE_ELLIPSE:
			%CreateEllipseContainer.show()
		CurvedLines2D.SVSEditMode.CREATE_RECT:
			%CreateRectContainer.show()
		CurvedLines2D.SVSEditMode.NONE:
			%SelectModeContainer.show()
		CurvedLines2D.SVSEditMode.PENCIL:
			%PencilToolContainer.show()
		CurvedLines2D.SVSEditMode.BRUSH:
			%BrushToolContainer.show()
		_:
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
	%CircleButton.disabled = false
	%RectangleButton.disabled = false


func set_default_mode() -> void:
	%EditButton.button_pressed = true


func _disable_and_toggle_off(btn : BaseButton) -> void:
	btn.disabled = true
	btn.button_pressed = false


func disable_svs_editors(disable_all := false) -> void:
	_disable_and_toggle_off(%RotateButton)
	_disable_and_toggle_off(%TranslateButton)
	_disable_and_toggle_off(%ResizeButton)
	_disable_and_toggle_off(%FlipHorizontalButton)
	_disable_and_toggle_off(%FlipVerticalButton)
	_disable_and_toggle_off(%BonePaintButton)
	#_disable_and_toggle_off(%EditButton)
	_disable_and_toggle_off(%KnifeButton)
	if disable_all:
		_disable_and_toggle_off(%BrushButton)
		_disable_and_toggle_off(%MergeButton)
		_disable_and_toggle_off(%PencilButton)
		_disable_and_toggle_off(%CircleButton)
		_disable_and_toggle_off(%RectangleButton)
	else:
		%BrushButton.disabled = false
		%MergeButton.disabled = false
		%PencilButton.disabled = false
		%CircleButton.disabled = false
		%RectangleButton.disabled = false



func disable_all_editors() -> void:
	disable_svs_editors(true)


func sync_draw_settings() -> void:
	brush_size_x_input.set_value_no_signal(CurvedLines2D._get_brush_size_x())
	brush_size_y_input.set_value_no_signal(CurvedLines2D._get_brush_size_y())
	brush_rotation_input.set_value_no_signal(CurvedLines2D._get_brush_rotation())
	%BrushShapeOptionButton.select(CurvedLines2D._get_brush_shape())
	ProjectSettings.save()


func sync_svs_settings(svs : ScalableVectorShape2D) -> void:
	if svs not in EditorInterface.get_selection().get_selected_nodes():
		return
	%FillPickerButton.color = svs.fill_color
	%StrokePickerButton.color = svs.stroke_color
	stroke_width_input.set_value_no_signal(svs.stroke_width)
	if is_instance_valid(svs.polygon):
		%EnableFillCheckBox.set_pressed_no_signal(true)
	else:
		%EnableFillCheckBox.set_pressed_no_signal(false)

	if is_instance_valid(svs.line) or is_instance_valid(svs.poly_stroke):
		%EnableStrokeCheckBox.set_pressed_no_signal(true)
		%UseLine2DCheckButton.set_pressed_no_signal(is_instance_valid(svs.line))
	else:
		%EnableStrokeCheckBox.set_pressed_no_signal(false)
	_toggle_end_cap_disabled(not %UseLine2DCheckButton.button_pressed)

	%CollisionObjectTypeOptionButton.select(svs.get_collision_object_type())
	%BeginBoxCapToggleButton.set_pressed_no_signal(svs.begin_cap_mode == Line2D.LINE_CAP_BOX)
	%BeginNoCapToggleButton.set_pressed_no_signal(svs.begin_cap_mode == Line2D.LINE_CAP_NONE)
	%BeginRoundCapToggleButton.set_pressed_no_signal(svs.begin_cap_mode == Line2D.LINE_CAP_ROUND)
	%EndBoxCapToggleButton.set_pressed_no_signal(svs.end_cap_mode == Line2D.LINE_CAP_BOX)
	%EndNoCapToggleButton.set_pressed_no_signal(svs.end_cap_mode == Line2D.LINE_CAP_NONE)
	%EndRoundCapToggleButton.set_pressed_no_signal(svs.end_cap_mode == Line2D.LINE_CAP_ROUND)
	%LineJoinSharpToggleButton.set_pressed_no_signal(svs.line_joint_mode == Line2D.LINE_JOINT_SHARP)
	%LineJointRoundToggleButton.set_pressed_no_signal(svs.line_joint_mode == Line2D.LINE_JOINT_ROUND)
	%LineJointBevelToggleButton.set_pressed_no_signal(svs.line_joint_mode == Line2D.LINE_JOINT_BEVEL)
	%MiddleToggleButton.set_pressed_no_signal(svs.extrusion_direction == ScalableVectorShape2D.StrokeExtrusionDirection.MIDDLE)
	%InsideToggleButton.set_pressed_no_signal(svs.extrusion_direction == ScalableVectorShape2D.StrokeExtrusionDirection.INWARD)
	%OutsideToggleButton.set_pressed_no_signal(svs.extrusion_direction == ScalableVectorShape2D.StrokeExtrusionDirection.OUTWARD)
	for btn : BaseButton in [%PaintOrderButton0, %PaintOrderButton2, %PaintOrderButton3,
			%PaintOrderButton4, %PaintOrderButton5, %PaintOrderButton1]:
				btn.set_pressed_no_signal(false)
	var valid_paint_orders := SVSPropertySync.get_valid_orders(svs)
	var paint_order := (
		CurvedLines2D._get_default_paint_order()
			if CurvedLines2D._get_default_paint_order() in valid_paint_orders else
		valid_paint_orders.pop_front()
	)
	match paint_order:
		CurvedLines2D.PaintOrder.FILL_STROKE_MARKERS:
			%PaintOrderButton0.set_pressed_no_signal(true)
		CurvedLines2D.PaintOrder.STROKE_FILL_MARKERS:
			%PaintOrderButton1.set_pressed_no_signal(true)
		CurvedLines2D.PaintOrder.FILL_MARKERS_STROKE:
			%PaintOrderButton2.set_pressed_no_signal(true)
		CurvedLines2D.PaintOrder.MARKERS_FILL_STROKE:
			%PaintOrderButton3.set_pressed_no_signal(true)
		CurvedLines2D.PaintOrder.STROKE_MARKERS_FILL:
			%PaintOrderButton4.set_pressed_no_signal(true)
		CurvedLines2D.PaintOrder.MARKERS_STROKE_FILL:
			%PaintOrderButton5.set_pressed_no_signal(true)
	ProjectSettings.save()


func _make_number_input(lbl : String, value : float, min_value : float, max_value : float,
			suffix : String, step := 1.0, tooltip_text := "") -> EditorSpinSlider:
	var x_slider := EditorSpinSlider.new()
	x_slider.value = value
	x_slider.min_value = min_value
	x_slider.max_value = max_value
	x_slider.suffix = suffix
	x_slider.label = lbl
	x_slider.step = step
	x_slider.focus_exited.connect(ProjectSettings.save)
	x_slider.tooltip_text = tooltip_text
	return x_slider


func _is_property_sync_allowed() -> bool:
	if %BrushButton.button_pressed or %PencilButton.button_pressed:
		return false
	return true


func _on_fill_picker_button_color_changed(color : Color) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_FILL_COLOR, color)
	if _is_property_sync_allowed():
		SVSPropertySync.sync_fill_color(false, not _changing_color)
		_changing_color = true


func _on_fill_picker_button_popup_closed() -> void:
	ProjectSettings.save()
	_changing_color = false
	if _is_property_sync_allowed():
		SVSPropertySync.sync_fill_color(true)
		_changing_color = false


func _on_stroke_picker_button_color_changed(color : Color) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_STROKE_COLOR, color)
	if _is_property_sync_allowed():
		SVSPropertySync.sync_stroke_color(false, not _changing_color)
		_changing_color = true


func _on_stroke_picker_button_popup_closed() -> void:
	ProjectSettings.save()
	if _is_property_sync_allowed():
		SVSPropertySync.sync_stroke_color(true)
		_changing_color = false


func _on_stroke_check_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_STROKE_ENABLED, toggled_on)
	ProjectSettings.save()
	if _is_property_sync_allowed():
		SVSPropertySync.sync_stroke()


func _on_stroke_width_input_value_changed(new_value: float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_STROKE_WIDTH, new_value)
	if _is_property_sync_allowed():
		SVSPropertySync.sync_stroke_width()


func _on_fill_check_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_FILL_ENABLED, toggled_on)
	ProjectSettings.save()
	if _is_property_sync_allowed():
		SVSPropertySync.sync_polygon()


func _on_collision_object_type_option_button_type_selected(obj_type: ScalableVectorShape2D.CollisionObjectType) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ADD_COLLISION_TYPE, obj_type)
	ProjectSettings.save()
	if _is_property_sync_allowed():
		SVSPropertySync.sync_collision_object()


func _toggle_end_cap_disabled(is_disabled : bool) -> void:
	%EndBoxCapToggleButton.disabled = is_disabled
	%EndNoCapToggleButton.disabled = is_disabled
	%EndRoundCapToggleButton.disabled = is_disabled
	%BeginCapLabel.text = "Cap" if is_disabled else "Begin"

func _on_use_line_2d_check_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_USE_LINE_2D_FOR_STROKE, toggled_on)
	_toggle_end_cap_disabled(not toggled_on)
	if _is_property_sync_allowed():
		SVSPropertySync.sync_stroke()


func _on_paint_order_button_0_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.FILL_STROKE_MARKERS)
	ProjectSettings.save()
	if toggled_on and  _is_property_sync_allowed():
		SVSPropertySync.sync_paint_order()


func _on_paint_order_button_1_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.STROKE_FILL_MARKERS)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_paint_order()


func _on_paint_order_button_2_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.FILL_MARKERS_STROKE)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_paint_order()


func _on_paint_order_button_3_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.MARKERS_FILL_STROKE)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_paint_order()


func _on_paint_order_button_4_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.STROKE_MARKERS_FILL)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_paint_order()


func _on_paint_order_button_5_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_PAINT_ORDER,
			CurvedLines2D.PaintOrder.MARKERS_STROKE_FILL)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_paint_order()


func _on_begin_no_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_BEGIN_CAP,
			Line2D.LineCapMode.LINE_CAP_NONE)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_begin_cap()


func _on_begin_box_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_BEGIN_CAP,
			Line2D.LineCapMode.LINE_CAP_BOX)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_begin_cap()


func _on_begin_round_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_BEGIN_CAP,
			Line2D.LineCapMode.LINE_CAP_ROUND)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_begin_cap()


func _on_end_no_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_END_CAP,
			Line2D.LineCapMode.LINE_CAP_NONE)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_end_cap()


func _on_end_box_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_END_CAP,
			Line2D.LineCapMode.LINE_CAP_BOX)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_end_cap()


func _on_end_round_cap_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_END_CAP,
			Line2D.LineCapMode.LINE_CAP_ROUND)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_end_cap()


func _on_line_joint_sharp_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_JOINT_MODE,
			Line2D.LineJointMode.LINE_JOINT_SHARP)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_line_joint_mode()


func _on_line_joint_bevel_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_JOINT_MODE,
			Line2D.LineJointMode.LINE_JOINT_BEVEL)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_line_joint_mode()


func _on_line_joint_round_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_LINE_JOINT_MODE,
			Line2D.LineJointMode.LINE_JOINT_ROUND)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_line_joint_mode()


func _on_middle_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_EXTRUSION,
			ScalableVectorShape2D.StrokeExtrusionDirection.MIDDLE)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_extrusion_direction()


func _on_outside_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_EXTRUSION,
			ScalableVectorShape2D.StrokeExtrusionDirection.OUTWARD)
	ProjectSettings.save()
	if toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_extrusion_direction()


func _on_inside_toggle_button_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_DEFAULT_EXTRUSION,
			ScalableVectorShape2D.StrokeExtrusionDirection.INWARD)
	ProjectSettings.save()
	if  toggled_on and _is_property_sync_allowed():
		SVSPropertySync.sync_extrusion_direction()


func _on_expand_tab_button_toggled(toggled_on: bool) -> void:
	if (toggled_on):
		custom_minimum_size.y = tab_default_min_height
	elif (!toggled_on):
		custom_minimum_size.y = 0


func _on_keep_drawing_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_KEEP_DRAWING,
				CurvedLines2D.KeepDrawingBehavior.KEEP_DRAWING_ON_SAME_PARENT)
	else:
		ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_KEEP_DRAWING,
				CurvedLines2D.KeepDrawingBehavior.SELECT_DRAWN_SHAPE)
	ProjectSettings.save()
	for b : CheckBox in keep_drawing_checkboxes:
		b.set_pressed_no_signal(toggled_on)


func _on_create_empty_shape_button_pressed() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root is Node:
		warning_dialog.dialog_text = OPEN_SCENE_ERROR_MESSAGE
		warning_dialog.popup_centered()
		return
	var curve := Curve2D.new()
	var node_name := "Path"
	shape_created.emit(curve, scene_root, node_name)


# --- Create Ellipse / Circle ---
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


func _on_ellipse_rx_value_changed(new_value : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ELLIPSE_RX, new_value)


func _on_ellipse_ry_value_changed(new_value : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_ELLIPSE_RY, new_value)


# --- Create Rectangle ---
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


func _on_create_rect_button_mouse_entered() -> void:
	set_shape_preview.emit(_get_rect_curve())


func _on_create_rect_button_mouse_exited() -> void:
	set_shape_preview.emit(null)


func _on_rect_width_value_changed(new_value : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_RECT_WIDTH, new_value)


func _on_rect_height_value_changed(new_value : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_RECT_HEIGHT, new_value)


func _on_rect_rx_value_changed(new_value : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_RECT_RX, new_value)


func _on_rect_ry_value_changed(new_value : float) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_RECT_RY, new_value)


func _calibrate_ui_scale() -> void:
	var editor_scale = EditorInterface.get_editor_settings().get_setting("interface/editor/display_scale")
	var scale_factor = (editor_scale - 2) * 0.25 + 1
	if (editor_scale > 2):
		for child in %CreateTab.find_children("*", "", true):
			if (child.custom_minimum_size != Vector2(0,0)):
				child.custom_minimum_size.x = child.custom_minimum_size.x * scale_factor
				child.custom_minimum_size.y = child.custom_minimum_size.y * scale_factor


# --- Pencil Tool ---
func _on_close_path_check_box_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_CLOSE_PENCIL_PATH, toggled_on)
	ProjectSettings.save()


# --- Brush Tool ---
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


func _on_brush_shape_option_button_item_selected(opt: int) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_BRUSH_SHAPE, opt)
	ProjectSettings.save()
	brush_changed.emit()


func _on_fill_in_parent_check_box_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_BRUSH_FILL_IN_PARENT_SHAPE, toggled_on)
	ProjectSettings.save()

# --- Pencil and Brush Tool ---
func _on_granularity_value_changed(new_val) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_FREEHAND_DRAW_GRANULARITY, new_val)
	ProjectSettings.save()
	for gi in granularity_inputs:
		gi.set_value_no_signal(new_val)


func _on_fit_curve_check_box_toggled(toggled_on: bool) -> void:
	ProjectSettings.set_setting(CurvedLines2D.SETTING_NAME_APPLY_CURVE_FITTING, toggled_on)
	ProjectSettings.save()
	for fc : CheckBox in fit_curve_check_boxes:
		fc.set_pressed_no_signal(toggled_on)
