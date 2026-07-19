@tool
extends Control

var scalable_vector_shape_2d : ScalableVectorShape2D

func _enter_tree() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if 'assigned_node_changed' in scalable_vector_shape_2d:
		scalable_vector_shape_2d.assigned_node_changed.connect(_on_svs_assignment_changed)
	_on_svs_assignment_changed()


func _on_svs_assignment_changed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.path):
		%GotoPathButton.show()
		%GotoPathButton.disabled = false
		%CreatePathButton.hide()
		%CreatePathButton.disabled = true
	else:
		%GotoPathButton.hide()
		%GotoPathButton.disabled = true
		%CreatePathButton.show()
		%CreatePathButton.disabled = false


func _on_goto_path_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.path):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.path)


func _on_create_path_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	var new_path := Path2D.new()
	undo_redo.create_action("Add Path2D to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', new_path, true)
	if scalable_vector_shape_2d == EditorInterface.get_edited_scene_root():
		undo_redo.add_do_method(new_path, 'set_owner', scalable_vector_shape_2d)
	else:
		undo_redo.add_do_method(new_path, 'set_owner', scalable_vector_shape_2d.owner)
	undo_redo.add_do_reference(new_path)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'path', new_path)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', new_path)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'path', null)
	undo_redo.commit_action()
