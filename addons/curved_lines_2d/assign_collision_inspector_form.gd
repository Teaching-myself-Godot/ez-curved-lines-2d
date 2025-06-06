@tool
extends Control

class_name AssignCollisionInspectorForm

var scalable_vector_shape_2d : ScalableVectorShape2D
var create_button : Button
var select_button : Button

func _enter_tree() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	create_button = find_child("CreateCollisionButton")
	select_button = find_child("GotoCollisionButton")
	if 'assigned_node_changed' in scalable_vector_shape_2d:
		scalable_vector_shape_2d.assigned_node_changed.connect(_on_svs_assignment_changed)
	_on_svs_assignment_changed()


func _on_svs_assignment_changed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.collision_polygon):
		create_button.get_parent().hide()
		select_button.get_parent().show()
		create_button.disabled = true
		select_button.disabled = false
	else:
		create_button.get_parent().show()
		select_button.get_parent().hide()
		create_button.disabled = false
		select_button.disabled = true


func _on_goto_collision_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.collision_polygon):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.collision_polygon)


func _on_create_collision_button_pressed():
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if is_instance_valid(scalable_vector_shape_2d.collision_polygon):
		return

	var collision_polygon_2d := CollisionPolygon2D.new()
	var root := EditorInterface.get_edited_scene_root()
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Add CollisionPolygon2D to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', collision_polygon_2d, true)
	undo_redo.add_do_method(collision_polygon_2d, 'set_owner', root)
	undo_redo.add_do_reference(collision_polygon_2d)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'collision_polygon', collision_polygon_2d)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', collision_polygon_2d)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'collision_polygon', null)
	undo_redo.commit_action()
