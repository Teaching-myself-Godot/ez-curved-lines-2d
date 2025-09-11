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
		return

	_selected_animation_player = animation_player
	%HintLabel.hide()
	%SelectAnimationOptionButton.clear()
	for anim_name in animation_player.get_animation_list():
		%SelectAnimationOptionButton.add_item(anim_name)
	%SelectAnimationOptionButton.show()
	%CreateSpriteSheetButton.show()
	%FpsInputContainer.show()


func _on_create_sprite_sheet_button_pressed() -> void:
	if not _selected_animation_player is AnimationPlayer:
		return

	var anim_name : String = %SelectAnimationOptionButton.get_item_text(%SelectAnimationOptionButton.get_selected_id())
	var fps := fps_number_input.value
	var interval := 1.0 / fps
	_selected_animation_player.stop()
	_selected_animation_player.current_animation = anim_name
	_selected_animation_player.get_animation(anim_name)

	for idx in range(ceili(_selected_animation_player.current_animation_length / interval)):
		var pos = idx * interval
		if pos > _selected_animation_player.current_animation_length:
			pos = _selected_animation_player.current_animation_length
		print(pos)
		_selected_animation_player.seek(pos, true)
		var box : Dictionary[String, Vector2] = {}
		var im = await Line2DGeneratorInspectorPlugin._export_image(
			EditorInterface.get_edited_scene_root(), box
		)
		im.save_png("res://testing_" + str(idx) + ".png")
		print(box)
	_selected_animation_player.stop()


func _make_number_input(lbl : String, value : float, min_value : float, max_value : float, suffix : String, step := 1.0) -> EditorSpinSlider:
	var x_slider := EditorSpinSlider.new()
	x_slider.value = value
	x_slider.min_value = min_value
	x_slider.max_value = max_value
	x_slider.suffix = suffix
	x_slider.label = lbl
	x_slider.step = step
	return x_slider
