@tool
extends KeyframeButtonCapableInspectorFormBase

var scalable_vector_shape_2d : ScalableVectorShape2D


func _enter_tree() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if 'assigned_node_changed' in scalable_vector_shape_2d:
		scalable_vector_shape_2d.assigned_node_changed.connect(_on_svs_assignment_changed)
	_on_svs_assignment_changed()
	_initialize_keyframe_capabilities()


func _on_key_frame_capabilities_changed():
	%AddFillKeyFrameButton.visible = _is_key_frame_capable()
	%BatchInsertGradientKeyFrameButton.visible = _is_key_frame_capable()


func _on_svs_assignment_changed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.polygon):
		%CreateFillButton.get_parent().hide()
		%GotoPolygon2DButton.get_parent().show()
		%GradientFieldContainer.show()
		%GradientStopColorButtonContainer.show()
		%CreateFillButton.disabled = true
		%GotoPolygon2DButton.disabled = false
		%ColorPickerButton.color = scalable_vector_shape_2d.polygon.color
		%RadialGradientToggleButton.disabled = false
		%LinearGradientToggleButton.disabled = false
		%RemoveGradientToggleButton.disabled = false
		if scalable_vector_shape_2d.polygon.texture is GradientTexture2D:
			if scalable_vector_shape_2d.polygon.texture.fill == GradientTexture2D.FILL_RADIAL:
				%RadialGradientToggleButton.button_pressed = true
			else:
				%LinearGradientToggleButton.button_pressed = true
			_set_gradient_stop_color_buttons()
		elif scalable_vector_shape_2d.polygon.texture:
			%OtherTextureToggleButton.button_pressed = true
			%GradientStopColorButtonContainer.hide()
		else:
			%RemoveGradientToggleButton.button_pressed = true
			%GradientStopColorButtonContainer.hide()
	else:
		%CreateFillButton.get_parent().show()
		%GotoPolygon2DButton.get_parent().hide()
		%GradientFieldContainer.hide()
		%GradientStopColorButtonContainer.hide()
		%CreateFillButton.disabled = false
		%GotoPolygon2DButton.disabled = true
		%ColorPickerButton.color = CurvedLines2D._get_default_fill_color()
		%RadialGradientToggleButton.disabled = true
		%LinearGradientToggleButton.disabled = true
		%RemoveGradientToggleButton.disabled = true
		%RemoveGradientToggleButton.button_pressed = true


func _on_color_picker_button_color_changed(color: Color) -> void:
	if not is_instance_valid(scalable_vector_shape_2d.polygon):
		return
	scalable_vector_shape_2d.polygon.color = color


func _on_goto_polygon_2d_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.polygon):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.polygon)


func _on_create_fill_button_pressed():
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if is_instance_valid(scalable_vector_shape_2d.polygon):
		return

	var polygon_2d := Polygon2D.new()
	var root := EditorInterface.get_edited_scene_root()
	var undo_redo = EditorInterface.get_editor_undo_redo()
	polygon_2d.color = %ColorPickerButton.color
	undo_redo.create_action("Add Polygon2D to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', polygon_2d, true)
	undo_redo.add_do_method(polygon_2d, 'set_owner', root)
	undo_redo.add_do_reference(polygon_2d)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'polygon', polygon_2d)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', polygon_2d)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'polygon', null)
	undo_redo.commit_action()


func _set_texture(texture : Texture2D, texture_offset := Vector2.ZERO) -> void:
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set texture for %s" % str(scalable_vector_shape_2d))
	undo_redo.add_do_property(scalable_vector_shape_2d.polygon, 'texture', texture)
	undo_redo.add_do_property(scalable_vector_shape_2d.polygon, 'texture_offset', texture_offset)
	undo_redo.add_do_method(self, '_on_svs_assignment_changed')
	undo_redo.add_undo_property(scalable_vector_shape_2d.polygon, 'texture', scalable_vector_shape_2d.polygon.texture)
	undo_redo.add_undo_property(scalable_vector_shape_2d.polygon, 'texture_offset', scalable_vector_shape_2d.polygon.texture_offset)
	undo_redo.add_undo_method(self, '_on_svs_assignment_changed')
	undo_redo.commit_action()


func _update_stop_color(idx : int, color : Color) -> void:
	scalable_vector_shape_2d.polygon.texture.gradient.colors[idx] = color


func _handle_stop_color_undo_redo_action(idx : int, btn : ColorPickerButton, toggled_on : bool) -> void:
	var undo_redo = EditorInterface.get_editor_undo_redo()
	if toggled_on:
		undo_redo.create_action("Set stop color for %s" % str(scalable_vector_shape_2d))
		undo_redo.add_undo_property(scalable_vector_shape_2d.polygon.texture.gradient, 'colors',
				scalable_vector_shape_2d.polygon.texture.gradient.colors)
		undo_redo.add_undo_property(btn, 'color',
				scalable_vector_shape_2d.polygon.texture.gradient.colors[idx])
	else:
		var new_colors = scalable_vector_shape_2d.polygon.texture.gradient.colors.duplicate()
		new_colors[idx] = btn.color
		undo_redo.add_do_property(scalable_vector_shape_2d.polygon.texture.gradient, 'colors', new_colors)
		undo_redo.add_do_property(btn, 'color', btn.color)
		undo_redo.commit_action()


func _on_remove_gradient_toggle_button_button_down() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.polygon):
		return

	_set_texture(null)


func _set_gradient_stop_color_buttons() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.polygon):
		return
	if not scalable_vector_shape_2d.polygon.texture is GradientTexture2D:
		return

	for b in %StopColorButtonsContainer.get_children():
		b.queue_free()

	for idx in range(scalable_vector_shape_2d.polygon.texture.gradient.colors.size()):
		var color : Color = scalable_vector_shape_2d.polygon.texture.gradient.colors[idx]
		var new_button := ColorPickerButton.new()
		new_button.color = color
		new_button.color_changed.connect(func(c): _update_stop_color(idx, c))
		new_button.toggled.connect(func(toggled_on): _handle_stop_color_undo_redo_action(idx, new_button, toggled_on))
		new_button.custom_minimum_size = Vector2(40, 40)
		%StopColorButtonsContainer.add_child(new_button)


func _on_linear_gradient_toggle_button_button_down() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.polygon):
		return
	if (scalable_vector_shape_2d.polygon.texture is GradientTexture2D and
				scalable_vector_shape_2d.polygon.texture.fill == GradientTexture2D.FILL_LINEAR):
		return

	var box := scalable_vector_shape_2d.get_bounding_rect()
	var texture := _initialize_gradient(box)
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_set_texture(texture, -box.position)


func _on_radial_gradient_toggle_button_button_down() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.polygon):
		return
	if (scalable_vector_shape_2d.polygon.texture is GradientTexture2D and
				scalable_vector_shape_2d.polygon.texture.fill == GradientTexture2D.FILL_RADIAL):
		return

	var box := scalable_vector_shape_2d.get_bounding_rect()
	var texture := _initialize_gradient(box)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = -box.position / box.size
	texture.fill_to = (scalable_vector_shape_2d.get_farthest_point() - box.position) / box.size
	_set_texture(texture, -box.position)


static func _initialize_gradient(box : Rect2) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = ceil(box.size.x)
	texture.height = ceil(box.size.y)
	texture.gradient = Gradient.new()
	texture.gradient.colors = [Color.WHITE, Color.BLACK]
	texture.gradient.offsets = [0.0, 1.0]
	return texture


func _on_add_fill_key_frame_button_pressed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.polygon):
		add_key_frame(
			scalable_vector_shape_2d.polygon, "color", %ColorPickerButton.color
		)


func _on_batch_insert_gradient_key_frame_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d.polygon):
		return
	if not scalable_vector_shape_2d.polygon.texture is GradientTexture2D:
		return

	var p2d := scalable_vector_shape_2d.polygon
	var animation_name := animation_under_edit_button.get_item_text(animation_under_edit_button.get_selected_id())
	var animation_player := _find_animation_player(animation_name)
	var track_position := _guarded_get_track_position()
	var animation := _guarded_get_animation(animation_player)
	var path_to_node := _guarded_get_path_to_node(animation_player, p2d)
	if not animation:
		return
	if path_to_node.is_empty():
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Batch all gradient keyframes for %s on animation %s" % [str(p2d), str(animation)])
	_add_key_frame(undo_redo, animation, NodePath("%s:texture:gradient:colors" % path_to_node),
		track_position, p2d.texture.gradient.colors)
	_add_key_frame(undo_redo, animation, NodePath("%s:texture:gradient:offsets" % path_to_node),
		track_position, p2d.texture.gradient.offsets)
	_add_key_frame(undo_redo, animation, NodePath("%s:texture:fill_from" % path_to_node),
		track_position, p2d.texture.fill_from)
	_add_key_frame(undo_redo, animation, NodePath("%s:texture:fill_to" % path_to_node),
		track_position, p2d.texture.fill_to)

	undo_redo.commit_action()


func _on_color_picker_button_toggled(toggled_on: bool) -> void:
	if not is_instance_valid(scalable_vector_shape_2d.polygon):
		return
	var undo_redo = EditorInterface.get_editor_undo_redo()
	if toggled_on:
		undo_redo.create_action("Adjust Polygon2D color for %s" % str(scalable_vector_shape_2d))
		undo_redo.add_undo_property(scalable_vector_shape_2d.polygon, 'color', scalable_vector_shape_2d.polygon.color)
	else:
		undo_redo.add_do_property(scalable_vector_shape_2d.polygon, 'color', %ColorPickerButton.color)
		undo_redo.commit_action(false)
