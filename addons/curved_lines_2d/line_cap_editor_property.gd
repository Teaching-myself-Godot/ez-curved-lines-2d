@tool
extends EditorProperty

# The main control for editing the property.
var property_control : Control
# An internal value of the property.
var current_value := Line2D.LINE_CAP_NONE
# A guard against internal changes when the property is updated.
var updating = false

func _init():
	property_control = load("res://addons/curved_lines_2d/line_cap_toggle_buttons.tscn").instantiate()
	# Add the control as a direct child of EditorProperty node.
	add_child(property_control)
	# Make sure the control is able to retain the focus.
	add_focusable(property_control)
	# Setup the initial state and connect to the signal to track changes.
	property_control.changed.connect(_on_changed)


func _on_changed(cap : Line2D.LineCapMode) -> void:
	if updating:
		return
	current_value = cap
	emit_changed(get_edited_property(), current_value)


func _update_property() -> void:
	# Read the current value from the property.
	var new_value = get_edited_object()[get_edited_property()]
	if new_value == current_value:
		return

	# Update the control with the new value.
	updating = true
	current_value = new_value
	property_control.set_toggle_to(new_value)
	updating = false
