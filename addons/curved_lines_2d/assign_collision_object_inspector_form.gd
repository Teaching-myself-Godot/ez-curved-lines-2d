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
	if is_instance_valid(scalable_vector_shape_2d.collision_object):
		%GoToCollisionObjectButton.show()
		%CollisionObjectTypeOptionButton.hide()
	else:
		%GoToCollisionObjectButton.hide()
		%CollisionObjectTypeOptionButton.show()
		%CollisionObjectTypeOptionButton.select(0)


func _on_collision_object_type_option_button_type_selected(obj_type: ScalableVectorShape2D.CollisionObjectType) -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return

	match obj_type:
		ScalableVectorShape2D.CollisionObjectType.STATIC_BODY_2D:
			_assign_collision_object(StaticBody2D.new())
		ScalableVectorShape2D.CollisionObjectType.AREA_2D:
			_assign_collision_object(Area2D.new())
		ScalableVectorShape2D.CollisionObjectType.ANIMATABLE_BODY_2D:
			_assign_collision_object(AnimatableBody2D.new())
		ScalableVectorShape2D.CollisionObjectType.RIGID_BODY_2D:
			_assign_collision_object(RigidBody2D.new())
		ScalableVectorShape2D.CollisionObjectType.CHARACTER_BODY_2D:
			_assign_collision_object(CharacterBody2D.new())
		ScalableVectorShape2D.CollisionObjectType.PHYSICAL_BONE_2D:
			_assign_collision_object(PhysicalBone2D.new())
		_, ScalableVectorShape2D.CollisionObjectType.NONE:
			scalable_vector_shape_2d.collision_object = null


func _assign_collision_object(new_obj : CollisionObject2D) -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Add %s to %s " % [str(new_obj.name), str(scalable_vector_shape_2d)])
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', new_obj, true)
	if scalable_vector_shape_2d == EditorInterface.get_edited_scene_root():
		undo_redo.add_do_method(new_obj, 'set_owner', scalable_vector_shape_2d)
	else:
		undo_redo.add_do_method(new_obj, 'set_owner', scalable_vector_shape_2d.owner)
	undo_redo.add_do_reference(new_obj)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'collision_object', new_obj)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', new_obj)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'collision_object', null)
	undo_redo.commit_action()


func _on_go_to_collision_object_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.collision_object):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.collision_object)
