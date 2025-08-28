@tool
extends Control



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
