@tool
extends Control

signal create_empty_shape()

var spin_input : EditorSpinSlider
var node_rotate_input : EditorSpinSlider
var node_skew_input : EditorSpinSlider

var _prev_value_map : Dictionary[Node, Variant] = {}

func _ready() -> void:
	if not EditorInterface.get_selection().selection_changed.is_connected(_on_selection_changed):
		EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_on_selection_changed()
	spin_input = _make_number_input("Spin", 0.0, -180.0, 180.0, "°", 1.0, "Local Point Rotation (Spin)", false, false)
	%SpinContainer.add_child(spin_input)
	spin_input.value_changed.connect(_on_shape_prop_changed.bind("spin", deg_to_rad))
	spin_input.focus_exited.connect(_on_shape_prop_committed.bind("spin"))
	spin_input.value_focus_exited.connect(_on_shape_prop_committed.bind("spin"))

	# Node inputs
	node_rotate_input = _make_number_input("Rotate", 0.0, -360.0, 360.0, "°", 0.1, "Rotate Node", false, false)
	%NodeRotateInputContainer.add_child(node_rotate_input)
	node_rotate_input.value_changed.connect(_on_shape_prop_changed.bind("rotation", deg_to_rad))
	node_rotate_input.focus_exited.connect(_on_shape_prop_committed.bind("rotation"))
	node_rotate_input.value_focus_exited.connect(_on_shape_prop_committed.bind("rotation"))

	node_skew_input = _make_number_input("Skew", 0.0, -89.9, 89.9, "°", 0.1, "Skew Node", false, false)
	%NodeSkewInputContainer.add_child(node_skew_input)
	node_skew_input.value_changed.connect(_on_shape_prop_changed.bind("skew", deg_to_rad))
	node_skew_input.focus_exited.connect(_on_shape_prop_committed.bind("skew"))
	node_skew_input.value_focus_exited.connect(_on_shape_prop_committed.bind("skew"))


func _on_create_empty_shape_button_pressed() -> void:
	create_empty_shape.emit()


func sync_svs_settings(svs : ScalableVectorShape2D) -> void:
	%CreateEmptyShapeContainer.hide()
	%ShapeSettingsContainer.show()

	if svs.shape_type != ScalableVectorShape2D.ShapeType.PATH:
		%ShapeTypeSettingsContainer.show()
	else:
		%ShapeTypeSettingsContainer.hide()
	%OffsetInput.set_value_no_signal(svs.offset)
	%SizeInput.set_value_no_signal(svs.size)
	%RadiusInput.set_value_no_signal(Vector2(svs.rx, svs.ry))
	%NodePosInput.set_value_no_signal(svs.position)
	%NodeScaleInput.set_value_no_signal(svs.scale)
	spin_input.set_value_no_signal(rad_to_deg(svs.spin))
	node_rotate_input.set_value_no_signal(rad_to_deg(svs.rotation))
	node_skew_input.set_value_no_signal(rad_to_deg(svs.skew))


func _on_selection_changed() -> void:
	var sel := EditorInterface.get_selection().get_selected_nodes()
	if sel.filter(func(n): return n is ScalableVectorShape2D).is_empty():
		%CreateEmptyShapeContainer.show()
		%ShapeSettingsContainer.hide()


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


func _on_shape_prop_changed(new_val : Variant, field : String, transformer : Callable = func(x): return x) -> void:
	var sel := (EditorInterface.get_selection().get_selected_nodes()
		.filter(func(x): return x is ScalableVectorShape2D and x)
	)
	if sel.is_empty():
		return
	for svs : ScalableVectorShape2D in sel:
		if svs not in _prev_value_map:
			_prev_value_map[svs] = svs[field]
		var new_value = transformer.call(new_val)
		svs[field] = new_value


func _on_radius_input_value_changed(new_value: Vector2) -> void:
	var sel := (EditorInterface.get_selection().get_selected_nodes()
		.filter(func(x): return x is ScalableVectorShape2D and x)
		.filter(func(x : ScalableVectorShape2D): return x.shape_type != ScalableVectorShape2D.ShapeType.PATH)
	)
	if sel.is_empty():
		return
	for svs : ScalableVectorShape2D in sel:
		if svs not in _prev_value_map:
			_prev_value_map[svs] = Vector2(svs.rx, svs.ry)
		if svs.shape_type == ScalableVectorShape2D.ShapeType.RECT:
			svs.rx = new_value.x
			svs.ry = new_value.y
		else:
			svs.size = new_value * 2.0


func _on_shape_prop_committed(field : String) -> void:
	var sel := (EditorInterface.get_selection().get_selected_nodes()
		.filter(func(x): return x is ScalableVectorShape2D and x)
		.filter(func(svs): return svs in _prev_value_map)
	)
	if sel.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Update %s for %d shape%s" % [field, sel.size(), "" if sel.size() == 1 else "s"])
	for svs : ScalableVectorShape2D in sel:
		undo_redo.add_do_property(svs, field, svs[field])
		undo_redo.add_undo_property(svs, field, _prev_value_map[svs])
	undo_redo.commit_action()
	_prev_value_map.clear()


func _on_radius_input_commit_value() -> void:
	var sel := (EditorInterface.get_selection().get_selected_nodes()
		.filter(func(x): return x is ScalableVectorShape2D and x)
		.filter(func(svs): return svs in _prev_value_map)
	)
	if sel.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Update radius for %d shape%s" % [sel.size(), "" if sel.size() == 1 else "s"])
	for svs : ScalableVectorShape2D in sel:
		if svs.shape_type == ScalableVectorShape2D.ShapeType.ELLIPSE:
			undo_redo.add_do_property(svs, "size", svs.size)
			undo_redo.add_undo_property(svs, "size", _prev_value_map[svs] * 2.0)
		else:
			undo_redo.add_do_property(svs, "rx", svs.rx)
			undo_redo.add_do_property(svs, "ry", svs.ry)
			undo_redo.add_undo_property(svs, "rx", _prev_value_map[svs][0])
			undo_redo.add_undo_property(svs, "ry", _prev_value_map[svs][1])

	undo_redo.commit_action()
	_prev_value_map.clear()


func _on_offset_input_value_changed(new_value: Vector2) -> void:
	_on_shape_prop_changed(new_value, "offset")


func _on_size_input_value_changed(new_value: Vector2) -> void:
	_on_shape_prop_changed(new_value, "size")


func _on_node_pos_input_value_changed(new_value: Vector2) -> void:
	_on_shape_prop_changed(new_value, "position")


func _on_node_scale_input_value_changed(new_value: Vector2) -> void:
	_on_shape_prop_changed(new_value, "scale")


func _on_offset_input_commit_value() -> void:
	_on_shape_prop_committed("offset")


func _on_size_input_commit_value() -> void:
	_on_shape_prop_committed("size")


func _on_node_pos_input_commit_value() -> void:
	_on_shape_prop_committed("position")


func _on_node_scale_input_commit_value() -> void:
	_on_shape_prop_committed("scale")

