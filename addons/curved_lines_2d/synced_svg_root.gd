@tool
extends Node2D
class_name SyncedSVGRoot

@export_file_path("*.svg") var svg_resource_path : String: set = _set_svg_resource_path

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		if not EditorInterface.get_resource_filesystem().resources_reimported.is_connected(_on_resources_reloaded):
			EditorInterface.get_resource_filesystem().resources_reimported.connect(_on_resources_reloaded)
		_reload_svg_file()


func _on_resources_reloaded(resources : PackedStringArray) -> void:
	for path in resources:
		if path == svg_resource_path:
			_reload_svg_file()


func _set_svg_resource_path(path) -> void:
	var path_change : bool = svg_resource_path != path
	svg_resource_path = path
	if path_change and Engine.is_editor_hint():
		_reload_svg_file()


func _reload_svg_file() -> void:
	print("TODO: reload svg file: ", svg_resource_path)
