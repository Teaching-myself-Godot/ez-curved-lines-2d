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
	if is_instance_valid(scalable_vector_shape_2d.collision_polygon):
		%GotoCollisionButton.show()
		%GotoCollisionButton.disabled = false
		%CreateCollisionButton.hide()
		%CreateCollisionButton.disabled = true
	else:
		%GotoCollisionButton.hide()
		%GotoCollisionButton.disabled = true
		%CreateCollisionButton.show()
		%CreateCollisionButton.disabled = false


func _on_goto_collision_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.collision_polygon):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.collision_polygon)


func _on_create_collision_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	var new_poly := CollisionPolygon2D.new()
	undo_redo.create_action("Add CollisionPolygon2D to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', new_poly, true)
	if scalable_vector_shape_2d == EditorInterface.get_edited_scene_root():
		undo_redo.add_do_method(new_poly, 'set_owner', scalable_vector_shape_2d)
	else:
		undo_redo.add_do_method(new_poly, 'set_owner', scalable_vector_shape_2d.owner)
	undo_redo.add_do_reference(new_poly)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'collision_polygon', new_poly)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', new_poly)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'collision_polygon', null)
	undo_redo.commit_action()
