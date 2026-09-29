@tool
extends EditorImportPlugin
class_name ScalableSVGImportPlugin

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var importer = SVGImporter.new()
	var owner = Node2D.new()
	owner.name = source_file.get_file().replace(".svg", "").to_pascal_case()
	var imported = await importer.load_svg(source_file,owner)
	if imported == null:
		return ERR_CANT_ACQUIRE_RESOURCE
	var packed = PackedScene.new()
	var pack_err = packed.pack(owner)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "%s.%s" % [save_path, _get_save_extension()])

func _get_import_order() -> int:
	return 0

func _get_priority() -> float:
	return 1.0

func _get_visible_name() -> String:
	return "Scaleable Vector Shapes"

func _get_recognized_extensions() -> PackedStringArray:
	return ["svg"]

func _get_save_extension() -> String:
	return "tscn"

func _get_resource_type() -> String:
	return "PackedScene"

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return []

func _get_preset_count() -> int:
	return 0

func _get_importer_name() -> String:
	return "ScaleableVectorShapes2d.svg"
