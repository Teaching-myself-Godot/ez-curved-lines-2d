@tool
class_name BasicVector2Input extends VBoxContainer

signal value_changed(new_value : Vector2)

@export var label := "":
	set(x):
		label = x
		if is_node_ready():
			%Label.text = x

@export var suffix := "":
	set(x):
		suffix = x
		if is_node_ready():
			%XValueEditorSpinSlider.suffix = x
			%YValueEditorSpinSlider.suffix = x

@export var editing_integer := false:
	set(x):
		editing_integer = x
		if is_node_ready():
			%XValueEditorSpinSlider.editing_integer = x
			%YValueEditorSpinSlider.editing_integer = x

@export var min_value := 0.0:
	set(x):
		min_value = x
		if is_node_ready():
			%XValueEditorSpinSlider.min_value = x
			%YValueEditorSpinSlider.min_value = x

@export var max_value := 100.0:
	set(x):
		max_value = x
		if is_node_ready():
			%XValueEditorSpinSlider.max_value = x
			%YValueEditorSpinSlider.max_value = x

@export var step := 1.0:
	set(x):
		step = x
		if is_node_ready():
			%XValueEditorSpinSlider.step = x
			%YValueEditorSpinSlider.step = x

@export var exp_edit := false:
	set(x):
		exp_edit = x
		if is_node_ready():
			%XValueEditorSpinSlider.exp_edit = x
			%YValueEditorSpinSlider.exp_edit = x

@export var allow_greater := false:
	set(x):
		allow_greater = x
		if is_node_ready():
			%XValueEditorSpinSlider.allow_greater = x
			%YValueEditorSpinSlider.allow_greater = x

@export var allow_lesser := false:
	set(x):
		allow_lesser = x
		if is_node_ready():
			%XValueEditorSpinSlider.allow_lesser = x
			%YValueEditorSpinSlider.allow_lesser = x

@export var read_only := false:
	set(ro):
		read_only = ro
		if is_node_ready():
			%XValueEditorSpinSlider.read_only = ro
			%YValueEditorSpinSlider.read_only = ro

@export var value := Vector2.ZERO:
	set(new_val):
		value = new_val
		if _do_emit:
			if is_node_ready():
				%XValueEditorSpinSlider.value = new_val.x
				%YValueEditorSpinSlider.value = new_val.y
			value_changed.emit(new_val)
		else:
			if is_node_ready():
				%XValueEditorSpinSlider.set_value_no_signal(new_val.x)
				%YValueEditorSpinSlider.set_value_no_signal(new_val.y)

var _do_emit := true

func _ready() -> void:
	for x : EditorSpinSlider in [%XValueEditorSpinSlider, %YValueEditorSpinSlider]:
		x.suffix = suffix
		x.read_only = read_only
		x.editing_integer = editing_integer
		x.min_value = min_value
		x.max_value = max_value
		x.step = step
		x.allow_greater = allow_greater
		x.allow_lesser = allow_lesser
	%XValueEditorSpinSlider.value = value.x
	%YValueEditorSpinSlider.value = value.y
	%Label.text = label


func set_value_no_signal(new_val : Vector2):
	_do_emit = false
	value = new_val
	_do_emit = true


func _on_x_value_editor_spin_slider_value_changed(new_x: float) -> void:
	value = Vector2(
		new_x, value.y
	)


func _on_y_value_editor_spin_slider_value_changed(new_y: float) -> void:
	value = Vector2(
		value.x, new_y
	)
