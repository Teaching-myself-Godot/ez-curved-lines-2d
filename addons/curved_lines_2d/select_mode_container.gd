@tool
extends Control

signal create_empty_shape()

var spin_input : EditorSpinSlider

var node_x_pos_input : EditorSpinSlider
var node_y_pos_input : EditorSpinSlider
var node_x_scale_input : EditorSpinSlider
var node_y_scale_input : EditorSpinSlider
var node_rotate_input : EditorSpinSlider
var node_skew_input : EditorSpinSlider

func _ready() -> void:
	if not EditorInterface.get_selection().selection_changed.is_connected(_on_selection_changed):
		EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_on_selection_changed()
	spin_input = _make_number_input("Spin", 0.0, -180.0, 180.0, "°", 1.0, "Local Point Rotation (Spin)", false, false)
	%SpinContainer.add_child(spin_input)
	spin_input.value_changed.connect(_on_shape_prop_changed.bind("spin", -1, deg_to_rad))


func _on_create_empty_shape_button_pressed() -> void:
	create_empty_shape.emit()


func sync_svs_settings(svs : ScalableVectorShape2D) -> void:
	%CreateEmptyShapeContainer.hide()
	if svs.shape_type != ScalableVectorShape2D.ShapeType.PATH:
		%ShapeTypeSettingsContainer.show()
	else:
		%ShapeTypeSettingsContainer.hide()
	%OffsetInput.set_value_no_signal(svs.offset)
	%SizeInput.set_value_no_signal(svs.size)
	%RadiusInput.set_value_no_signal(Vector2(svs.rx, svs.ry))
	spin_input.set_value_no_signal(rad_to_deg(svs.spin))


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


func _on_shape_prop_changed(new_val : Variant, field : String, field_idx : int = -1, transformer : Callable = func(x): return x) -> void:
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


func _on_offset_input_value_changed(new_value: Vector2) -> void:
	_on_shape_prop_changed(new_value, "offset")


func _on_size_input_value_changed(new_value: Vector2) -> void:
	_on_shape_prop_changed(new_value, "size")


func _on_radius_input_value_changed(new_value: Vector2) -> void:
	var sel := (EditorInterface.get_selection().get_selected_nodes()
		.filter(func(x): return x is ScalableVectorShape2D and x)
		.filter(func(x : ScalableVectorShape2D): return x.shape_type != ScalableVectorShape2D.ShapeType.PATH)
	)
	if sel.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Update radius for %d shape%s" % [sel.size(), "" if sel.size() == 1 else "s"])
	for svs : ScalableVectorShape2D in sel:
		if svs.shape_type == ScalableVectorShape2D.ShapeType.RECT:
			undo_redo.add_do_property(svs, "rx", new_value.x)
			undo_redo.add_undo_property(svs, "rx", svs.rx)
			undo_redo.add_do_property(svs, "ry", new_value.y)
			undo_redo.add_undo_property(svs, "ry", svs.ry)
		else:
			undo_redo.add_do_property(svs, "size", new_value * 2.0)
			undo_redo.add_undo_property(svs, "size", svs.size)

	undo_redo.commit_action()
