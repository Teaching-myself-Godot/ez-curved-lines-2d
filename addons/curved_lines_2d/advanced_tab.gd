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
	var interval := 1.0 / fps
	_selected_animation_player.stop()
	_selected_animation_player.current_animation = anim_name
	_selected_animation_player.get_animation(anim_name)

	var boxes : Array[Dictionary] = []
	var images : Array[Image] = []
	var frame_count := ceili(_selected_animation_player.current_animation_length / interval)
	%StatusLabel.show()
	%StatusLabel.text = "Exporting %d frames" % frame_count
	%CreateSpriteSheetButton.disabled = true
	%CreateSpriteSheetButton.text = "Creating..."
	for idx in range(frame_count):
		var pos = idx * interval
		if pos > _selected_animation_player.current_animation_length:
			pos = _selected_animation_player.current_animation_length
		_selected_animation_player.seek(pos, true)
		_selected_animation_player.pause()
		var box : Dictionary[String, Vector2] = {}
		var im = await Line2DGeneratorInspectorPlugin._export_image(
			EditorInterface.get_edited_scene_root(), box
		)
		boxes.append(box)
		images.append(im)
	_selected_animation_player.stop()

	var min_x = boxes.map(func(box): return box["tl"].x).min()
	var min_y = boxes.map(func(box): return box["tl"].y).min()
	var max_x = boxes.map(func(box): return box["br"].x).max()
	var max_y = boxes.map(func(box): return box["br"].y).max()

	if %ExportAsSpritesheetCheckButton.button_pressed:
		var frame_w := ceili(max_x) - floori(min_x)
		var im : Image = Image.create_empty(
			frame_w * images.size(),
			ceili(max_y) - floor(min_y), false, images[0].get_format())
		for idx in images.size():
			for x in images[idx].get_size().x:
				for y in images[idx].get_size().y:
					im.set_pixel(
						(idx * frame_w) + (floori(boxes[idx]["tl"].x) - min_x + x),
						floori(boxes[idx]["tl"].y) - min_y + y,
						images[idx].get_pixel(x, y)
					)
		im.save_png(file_path)
	else:
		for idx in images.size():
			var im : Image = Image.create_empty(ceili(max_x) - floori(min_x), ceili(max_y) - floor(min_y), false, images[idx].get_format())
			for x in images[idx].get_size().x:
				for y in images[idx].get_size().y:
					im.set_pixel(floori(boxes[idx]["tl"].x) - min_x + x, floori(boxes[idx]["tl"].y) - min_y + y, images[idx].get_pixel(x, y))
			im.save_png(file_path.replacen(".png", "_%d.png" % idx))

	%StatusLabel.text = "Exported %d frames" % frame_count
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
