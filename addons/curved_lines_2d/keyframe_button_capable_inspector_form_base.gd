@tool
extends Control

class_name KeyframeButtonCapableInspectorFormBase

var animation_player_editor : Control
var animation_under_edit_button : OptionButton
var animation_postion_spinbox : SpinBox

func _initialize_keyframe_capabilities():
	animation_player_editor = EditorInterface.get_base_control().find_child("*AnimationPlayerEditor*", true, false)
	if not is_instance_valid(animation_player_editor):
		# Fallback locator for Godot 4.6-stable (and later?)
		var editor_bottom_panel = EditorInterface.get_base_control().find_child("*EditorBottomPanel*", true, false)
		animation_player_editor = editor_bottom_panel.find_child("Animation", true, false)

	if is_instance_valid(animation_player_editor):
		animation_under_edit_button = animation_player_editor.find_child("*OptionButton*", true, false)
		animation_postion_spinbox = animation_player_editor.find_child("*SpinBox*", true, false)
		animation_player_editor.visibility_changed.connect(_on_key_frame_capabilities_changed)
		if is_instance_valid(animation_under_edit_button):
			animation_under_edit_button.item_selected.connect(func(_sid): _on_key_frame_capabilities_changed)
	_on_key_frame_capabilities_changed()


func _on_key_frame_capabilities_changed():
	printerr("_on_key_frame_capabilities_changed should be overridden")


func _is_key_frame_capable() -> bool:
	if not is_instance_valid(animation_player_editor):
		return false
	if not is_instance_valid(animation_under_edit_button):
		return false
	if animation_under_edit_button.get_selected_id() < 0:
		return false
	if not animation_player_editor.visible:
		return false
	if not _find_animation_player(
		animation_under_edit_button.get_item_text(animation_under_edit_button.get_selected_id())):
		return false
	return true


func _find_animation_player(with_anim_name : String) -> AnimationPlayer:
	for n in EditorInterface.get_edited_scene_root().find_children("*", "AnimationPlayer", true):
		if n is AnimationPlayer and (n as AnimationPlayer).has_animation(with_anim_name):
			return n
	return null


func _guarded_get_path_to_node(animation_player : AnimationPlayer, node : Node) -> String:
	var root_node := animation_player.get_node(animation_player.root_node)
	if not is_instance_valid(root_node):
		printerr("Could not find root node for %s by path: %s" % [str(animation_player), animation_player.root_node])
		return ""
	var path_to_node = root_node.get_path_to(node)
	if path_to_node.is_empty():
		printerr("Could not find a path from AnimationPlayer's root node (%s) to this node (%s)" % [
				animation_player.root_node, str(node)])
		return ""
	return path_to_node


func _guarded_get_animation(animation_player : AnimationPlayer) -> Animation:
	if not is_instance_valid(animation_player):
		return null
	if not is_instance_valid(animation_under_edit_button):
		return null
	var selected_anim_id := animation_under_edit_button.get_selected_id()
	var selected_anim_name := ""
	if selected_anim_id < 0:
		return null
	else:
		selected_anim_name = animation_under_edit_button.get_item_text(selected_anim_id)
	if not animation_player.has_animation(selected_anim_name):
		printerr("Could not find animation %s in in %s" % [selected_anim_name, str(animation_player)])
		return null
	return animation_player.get_animation(selected_anim_name)


func _guarded_get_track_position() -> float:
	if is_instance_valid(animation_postion_spinbox):
		return animation_postion_spinbox.value
	return 0.0


func add_key_frame(node : Node, property_path : String, val : Variant):
	var animation_name := animation_under_edit_button.get_item_text(animation_under_edit_button.get_selected_id())
	var animation_player := _find_animation_player(animation_name)
	var track_position := _guarded_get_track_position()
	var animation := _guarded_get_animation(animation_player)
	var path_to_node := _guarded_get_path_to_node(animation_player, node)
	if not animation:
		return
	if path_to_node.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Add key frame on %s of %s" % [property_path, str(node)])
	_add_key_frame(undo_redo, animation, NodePath("%s:%s" % [path_to_node, property_path]),
			track_position, val)
	undo_redo.commit_action()


func _add_key_frame(undo_redo : EditorUndoRedoManager, animation : Animation, node_path : NodePath,
			track_position : float, val : Variant):
	undo_redo.add_do_reference(animation)
	var t_idx := animation.find_track(node_path, Animation.TrackType.TYPE_VALUE)
	if t_idx < 0:
		undo_redo.add_do_method(self, 'add_anim_track_if_absent', animation, node_path)
		undo_redo.add_undo_method(self, 'remove_anim_track_by_path', animation, node_path)

	undo_redo.add_do_method(self, 'add_key_to_anim_track_by_path', animation, node_path,
			track_position, val)

	var k_idx := animation.track_find_key(t_idx, track_position) if t_idx > -1 else -1
	if k_idx < 0:
		undo_redo.add_undo_method(self, 'remove_key_from_anim_track_by_path_and_position', animation,
				node_path, track_position)
	else:
		undo_redo.add_undo_method(self, 'add_key_to_anim_track_by_path', animation, node_path,
			track_position, animation.track_get_key_value(t_idx, k_idx))


func remove_key_from_anim_track_by_path_and_position(animation : Animation, node_path : NodePath,
			track_position : float):
	var t_idx := animation.find_track(node_path, Animation.TrackType.TYPE_VALUE)
	if t_idx < 0:
		return
	var k_idx := animation.track_find_key(t_idx, track_position)
	if k_idx < 0:
		return
	animation.track_remove_key(t_idx, k_idx)


func add_key_to_anim_track_by_path(animation : Animation, node_path : NodePath,
			track_position : float, val : Variant):
	var t_idx := animation.find_track(node_path, Animation.TrackType.TYPE_VALUE)
	if t_idx < 0:
		return
	animation.track_insert_key(t_idx, track_position, val)


func add_anim_track_if_absent(animation : Animation, node_path : NodePath):
	var t_idx := animation.find_track(node_path, Animation.TrackType.TYPE_VALUE)
	if t_idx < 0:
		t_idx = animation.add_track(Animation.TrackType.TYPE_VALUE)
		animation.track_set_path(t_idx, node_path)


func remove_anim_track_by_path(animation : Animation, node_path : NodePath) -> void:
	var t_idx := animation.find_track(node_path, Animation.TrackType.TYPE_VALUE)
	if t_idx > -1:
		animation.remove_track(t_idx)
