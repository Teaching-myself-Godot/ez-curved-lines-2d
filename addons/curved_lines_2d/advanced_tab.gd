@tool
extends Control

var _init_hint_label_text := ""
var _selected_animation_player : AnimationPlayer
var fps_number_input : EditorSpinSlider

func _enter_tree() -> void:
	_init_hint_label_text = $%HintLabel.text
	fps_number_input = _make_number_input("FPS", 60.0, 5.0, 120.0, "fps", 1.0)
	%FpsInputContainer.add_child(fps_number_input)


func _on_export_as_png_button_pressed() -> void:
	var selected_node := EditorInterface.get_selection().get_selected_nodes().pop_back()
	Line2DGeneratorInspectorPlugin._on_export_png_button_pressed(selected_node)


func _on_export_as_baked_scene_button_pressed() -> void:
	var selected_node := EditorInterface.get_selection().get_selected_nodes().pop_back()
	Line2DGeneratorInspectorPlugin._show_exported_scene_dialog(
		selected_node, Line2DGeneratorInspectorPlugin._export_baked_scene
	)


func _on_export_as_3d_scene_button_pressed() -> void:
	var selected_node := EditorInterface.get_selection().get_selected_nodes().pop_back()
	Line2DGeneratorInspectorPlugin._show_exported_scene_dialog(
		selected_node, Line2DGeneratorInspectorPlugin._export_3d_scene
	)


func set_animation_player(animation_player : AnimationPlayer) -> void:
	if not animation_player is AnimationPlayer:
		%HintLabel.text = _init_hint_label_text
		%HintLabel.show()
		%SelectAnimationOptionButton.hide()
		%CreateSpriteSheetButton.hide()
		%FpsInputContainer.hide()
		%ExportAsSpritesheetCheckButton.hide()
		%StatusLabel.hide()
		return

	_selected_animation_player = animation_player
	%HintLabel.hide()
	%StatusLabel.text = ""
	%SelectAnimationOptionButton.clear()
	%SelectAnimationOptionButton.add_item(" - select animation -")
	%SelectAnimationOptionButton.select(0)
	%SelectAnimationOptionButton.set_item_disabled(0, true)
	for anim_name in animation_player.get_animation_list():
		if anim_name == "RESET":
			continue
		%SelectAnimationOptionButton.add_item(anim_name)
	%SelectAnimationOptionButton.show()
	%CreateSpriteSheetButton.show()
	%FpsInputContainer.show()
	%ExportAsSpritesheetCheckButton.show()


func _on_create_sprite_sheet_button_pressed() -> void:
	if not _selected_animation_player is AnimationPlayer:
		return
	var dialog := EditorFileDialog.new()
	var anim_name : String = %SelectAnimationOptionButton.get_item_text(%SelectAnimationOptionButton.get_selected_id())
	dialog.add_filter("*.png", "PNG")
	dialog.current_file = ("%s_%s" % [
			EditorInterface.get_edited_scene_root().name,
			anim_name
	]).to_snake_case()

	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.file_selected.connect(func(path): _on_animation_file_name_chosen(path, anim_name, dialog))
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 400))


func _on_animation_file_name_chosen(file_path : String, anim_name : String, dialog : EditorFileDialog):
	dialog.queue_free()
	var fps := fps_number_input.value
	%StatusLabel.show()
	%CreateSpriteSheetButton.disabled = true
	%CreateSpriteSheetButton.text = "Creating..."

	var sprite_frames := await SVSSceneExporter.export_sprite_frames(
			EditorInterface.get_edited_scene_root(), _selected_animation_player, anim_name, fps,
			EditorInterface.get_base_control(), func(status_msg : String): %StatusLabel.text = status_msg
	)

	if %ExportAsSpritesheetCheckButton.button_pressed:
		var im : Image = Image.create_empty(
			sprite_frames[0].get_size().x * sprite_frames.size(),
			sprite_frames[0].get_size().y, false, sprite_frames[0].get_format())
		for idx in sprite_frames.size():
			im.blit_rect(sprite_frames[idx],
					Rect2i(Vector2i.ZERO, sprite_frames[idx].get_size()),
					Vector2i(sprite_frames[0].get_size().x * idx, 0)
			)
		im.save_png(file_path)
	else:
		for idx in sprite_frames.size():
			sprite_frames[idx].save_png(file_path.replacen(".png", "_%d.png" % idx))

	%StatusLabel.text = "Exported %d frames" % sprite_frames.size()
	%CreateSpriteSheetButton.disabled = false
	%CreateSpriteSheetButton.text = "Create"
	EditorInterface.get_resource_filesystem().scan()


func _make_number_input(lbl : String, value : float, min_value : float, max_value : float, suffix : String, step := 1.0) -> EditorSpinSlider:
	var x_slider := EditorSpinSlider.new()
	x_slider.value = value
	x_slider.min_value = min_value
	x_slider.max_value = max_value
	x_slider.suffix = suffix
	x_slider.label = lbl
	x_slider.step = step
	return x_slider
