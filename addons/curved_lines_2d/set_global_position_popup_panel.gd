@tool
extends PopupPanel

signal value_changed(value : Vector2, meta_name : String, point_idx : int)

var x_pos_input : EditorSpinSlider
var y_pos_input : EditorSpinSlider
var meta_name := "_hover_point_idx"
var point_idx : int = 0
var _dragging := false
var _drag_start := Vector2.ZERO

func _enter_tree() -> void:
	visible = false
	x_pos_input = _mk_input()
	y_pos_input = _mk_input()
	%XPosInputContainer.add_child(x_pos_input)
	%YPosInputContainer.add_child(y_pos_input)
	if not x_pos_input.value_changed.is_connected(_on_value_changed):
		x_pos_input.value_changed.connect(_on_value_changed)
	if not y_pos_input.value_changed.is_connected(_on_value_changed):
		y_pos_input.value_changed.connect(_on_value_changed)


func _on_button_pressed() -> void:
	hide()


func _on_value_changed(_v : Variant = null):
	value_changed.emit(Vector2(x_pos_input.value, y_pos_input.value), meta_name, point_idx)


func popup_with_value(metadata : Dictionary, snapped : bool, snap_step : float):
	point_idx = metadata['point_idx']
	meta_name = metadata['meta_name']
	x_pos_input.set_value_no_signal(metadata['global_pos'].x)
	y_pos_input.set_value_no_signal(metadata['global_pos'].y)
	if snapped:
		x_pos_input.step = snap_step
		y_pos_input.step = snap_step
	else:
		x_pos_input.step = 0.001
		y_pos_input.step = 0.001
	_on_value_changed()
	popup_centered()


func _mk_input() -> EditorSpinSlider:
	var num_input := EditorSpinSlider.new()
	num_input.suffix = "px"
	num_input.hide_slider = true
	num_input.value = 0.0
	num_input.editing_integer = false
	num_input.allow_lesser = true
	num_input.allow_greater = true
	num_input.step = 0.001
	return num_input


func _on_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _dragging:
				_dragging = true
				_drag_start = EditorInterface.get_base_control().get_local_mouse_position()
		else:
			_dragging = false
	if event is InputEventMouseMotion and _dragging:
		position += Vector2i(EditorInterface.get_base_control().get_local_mouse_position() - _drag_start)
		_drag_start = EditorInterface.get_base_control().get_local_mouse_position()
