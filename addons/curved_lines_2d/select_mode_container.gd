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
	x_size_input = _make_number_input("Size", 100.0, 1.0, 1000.0, "px", 1.0, "X Size", false, true)
	%XSizeInputContainer.add_child(x_size_input)
	y_size_input = _make_number_input("Size", 100.0, 1.0, 1000.0, "px", 1.0, "Y Size", false, true)
	%YSizePosInputContainer.add_child(y_size_input)
	spin_input = _make_number_input("Spin", 0.0, -180.0, 180.0, "°", 1.0, "Local Point Rotation (Spin)", false, false)
	%SpinContainer.add_child(spin_input)
	rx_input = _make_number_input("X Corner Radius", 0.0, 0.0, 500.0, "px", 1.0, "X Corner radius", false, true)
	%RXContainer.add_child(rx_input)
	ry_input = _make_number_input("Y Corner Radius", 0.0, 0.0, 500.0, "px", 1.0, "Y Corner radius", false, true)
	%RYContainer.add_child(ry_input)
	x_offset_input.value_changed.connect(_on_shape_prop_changed.bind("offset", 0))
	y_offset_input.value_changed.connect(_on_shape_prop_changed.bind("offset", 1))
	x_size_input.value_changed.connect(_on_shape_prop_changed.bind("size", 0))
	y_size_input.value_changed.connect(_on_shape_prop_changed.bind("size", 1))
	spin_input.value_changed.connect(_on_shape_prop_changed.bind("spin", -1, deg_to_rad))
	rx_input.value_changed.connect(_on_shape_prop_changed.bind("rx"))
	ry_input.value_changed.connect(_on_shape_prop_changed.bind("ry"))


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
	spin_input.set_value_no_signal(rad_to_deg(svs.spin))
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


func _on_convert_to_path_button_pressed() -> void:
	var sel := (EditorInterface.get_selection().get_selected_nodes()
		.filter(func(x): return x is ScalableVectorShape2D and x)
		.filter(func(x : ScalableVectorShape2D): return x.shape_type != ScalableVectorShape2D.ShapeType.PATH)
	)
	if sel.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Convert %d shape%s to path" % [sel.size(), "" if sel.size() == 1 else "s"])
	for svs : ScalableVectorShape2D in sel:
		undo_redo.add_do_property(svs, "shape_type", ScalableVectorShape2D.ShapeType.PATH)
		undo_redo.add_undo_property(svs, "shape_type", svs.shape_type)
	undo_redo.commit_action()


func _on_shape_prop_changed(new_val : float, field : String, field_idx : int = -1, transformer : Callable = func(x): return x) -> void:
	var sel := (EditorInterface.get_selection().get_selected_nodes()
		.filter(func(x): return x is ScalableVectorShape2D and x)
		.filter(func(x : ScalableVectorShape2D): return x.shape_type != ScalableVectorShape2D.ShapeType.PATH)
	)
	if sel.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Update %s for %d shape%s" % [field, sel.size(), "" if sel.size() == 1 else "s"])
	for svs : ScalableVectorShape2D in sel:
		var new_value = svs[field] if field_idx > -1 else transformer.call(new_val)
		if field_idx > -1:
			new_value[field_idx] = transformer.call(new_val)
		undo_redo.add_do_property(svs, field, new_value)
		undo_redo.add_undo_property(svs, field, svs[field])
	undo_redo.commit_action()
