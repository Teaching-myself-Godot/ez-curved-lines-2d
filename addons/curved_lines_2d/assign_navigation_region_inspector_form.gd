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
	if is_instance_valid(scalable_vector_shape_2d.navigation_region):
		%GoToNavigationRegionButton.show()
		%AddNavigationRegionButton.hide()
	else:
		%GoToNavigationRegionButton.hide()
		%AddNavigationRegionButton.show()


func _on_add_navigation_region_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return

	var new_obj := NavigationRegion2D.new()
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Add NavigationRegion2D to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', new_obj, true)
	if scalable_vector_shape_2d == EditorInterface.get_edited_scene_root():
		undo_redo.add_do_method(new_obj, 'set_owner', scalable_vector_shape_2d)
	else:
		undo_redo.add_do_method(new_obj, 'set_owner', scalable_vector_shape_2d.owner)
	undo_redo.add_do_reference(new_obj)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'navigation_region', new_obj)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', new_obj)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'navigation_region', null)
	undo_redo.commit_action()


func _on_go_to_navigation_region_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.navigation_region):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.navigation_region)
