@tool
extends Control

signal create_empty_shape()

var x_offset_input : EditorSpinSlider
var y_offset_input : EditorSpinSlider
var x_size_input : EditorSpinSlider
var y_size_input : EditorSpinSlider
var spin_input : EditorSpinSlider
var rx_input : EditorSpinSlider
var ry_input : EditorSpinSlider


func _ready() -> void:
	if not EditorInterface.get_selection().selection_changed.is_connected(_on_selection_changed):
		EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_on_selection_changed()
	x_offset_input = _make_number_input("Offset", 0.0, 0.0, 1000.0, "px", 1.0, "X Offset position", true, true)
	%XOffsetInputContainer.add_child(x_offset_input)
	y_offset_input = _make_number_input("Offset", 0.0, 0.0, 1000.0, "px", 1.0, "Y Offset position", true, true)
	%YOffsetPosInputContainer.add_child(y_offset_input)
	x_size_input = _make_number_input("Offset", 100.0, 1.0, 1000.0, "px", 1.0, "X Size", false, true)
	%XSizeInputContainer.add_child(x_size_input)
	y_size_input = _make_number_input("Offset", 100.0, 1.0, 1000.0, "px", 1.0, "Y Size", false, true)
	%YSizePosInputContainer.add_child(y_size_input)
	spin_input = _make_number_input("Spin", 0.0, -180.0, 180.0, "°", 1.0, "Local Point Rotation (Spin)", false, false)
	%SpinContainer.add_child(spin_input)
	rx_input = _make_number_input("X Radius", 0.0, 0.0, 500.0, "px", 1.0, "X Corner radius", false, true)
	%RXContainer.add_child(rx_input)
	ry_input = _make_number_input("Y Radius", 0.0, 0.0, 500.0, "px", 1.0, "Y Corner radius", false, true)
	%RYContainer.add_child(ry_input)


func _on_create_empty_shape_button_pressed() -> void:
	create_empty_shape.emit()


func sync_svs_settings(svs : ScalableVectorShape2D) -> void:
	%CreateEmptyShapeContainer.hide()
	if svs.shape_type != ScalableVectorShape2D.ShapeType.PATH:
		%ShapeTypeSettingsContainer.show()
	else:
		%ShapeTypeSettingsContainer.hide()
	x_offset_input.set_value_no_signal(svs.offset.x)
	y_offset_input.set_value_no_signal(svs.offset.y)
	x_size_input.set_value_no_signal(svs.size.x)
	y_size_input.set_value_no_signal(svs.size.y)
	spin_input.set_value_no_signal(svs.spin)
	rx_input.set_value_no_signal(svs.rx)
	ry_input.set_value_no_signal(svs.ry)


func _on_selection_changed() -> void:
	var sel := EditorInterface.get_selection().get_selected_nodes()
	if sel.filter(func(n): return n is ScalableVectorShape2D).is_empty():
		%CreateEmptyShapeContainer.show()
		%ShapeTypeSettingsContainer.hide()



func _make_number_input(lbl : String, value : float, min_value : float, max_value : float,
			suffix : String, step := 1.0, tooltip_text := "", allow_lesser  := false,
			allow_greater := false) -> EditorSpinSlider:
	var x_slider := EditorSpinSlider.new()
	x_slider.value = value
	x_slider.min_value = min_value
	x_slider.max_value = max_value
	x_slider.suffix = suffix
	x_slider.label = lbl
	x_slider.step = step
	x_slider.focus_exited.connect(ProjectSettings.save)
	x_slider.tooltip_text = tooltip_text
	x_slider.allow_greater = allow_greater
	x_slider.allow_lesser = allow_lesser
	return x_slider
