@tool
extends EditorImportPlugin
class_name ScalableSVGImportPlugin

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var importer = SVGImporter.new(
		options["Use Scalable Vector Shapes"],
		true,
		true,
		options["Antialiased"],
		options["Use Line2D"],
		options["Collision Type"],
		options["Update Curves at runtime"],
		true,
		options["Tolerance Degrees"],
		options["Max Stages"],
		options["Antialiased Line2D"])
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
	return 1.1

func _get_visible_name() -> String:
	return "Scaleable Vector Shapes"

func _get_recognized_extensions() -> PackedStringArray:
	return ["svg"]

func _get_save_extension() -> String:
	return "tscn"

func _get_resource_type() -> String:
	return "PackedScene"

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [{
		"name": "Use Scalable Vector Shapes",
		"default_value": true,
		"description": "If true, import shapes nodes as [ScalableVectorShape2D] that manages godot native nodes via [member ScalableVectorShape2D.line], [member ScalableVectorShape2D.polygon], [member ScalableVectorShape2D.collision_object] and [member ScalableVectorShape2D.polystroke]. If false, import only [Polygon2D], [Line2D] and [CollisionPolygon2D], unmanaged by [ScalableVectorShape2D]"
	},
	{
		"name": "Use Line2D",
		"default_value": true,
		"description": "If true, import SVG Strokes as [Line2D], assigning [member ScalableVectorShape2D.line], otherwise import SVG Strokes as [Polygon2D], assigning [member ScalableVectorShape2D.poly_stroke]"
	},
	{
		"name": "Antialiased",
		"default_value": true,
		"description": "Toggle [member Line2D.antialiased] and [Polygon2D.antialiased]"
	},
	{
		"name": "Antialiased Line2D",
		"default_value": false,
		"description": "Sets [member Line2D.texture] to a blurred texture, with repeat."
	},
	{
		"name": "Update Curves at runtime",
		"default_value": true,
		"description": "Sets [member ScalableVectorShape2D.update_curve_at_runtime] for all imported shapes"
	},
	{
		"name": "Collision Type",
		"default_value": ScalableVectorShape2D.CollisionObjectType.NONE,
		"property_hint": PROPERTY_HINT_ENUM,
		"hint_string": ScalableVectorShape2D.CollisionObjectType.keys().map(func (elem): return str(elem).to_lower().capitalize()).reduce(func (prev,curr): return str(prev) + "," + str(curr)),
		"description": "The type of [CollisionObject2D] to wrap around [CollisionPolygon2D] nodes managed by [member ScalableVectorShape2D.collision_object]"
	},
	{
		"name": "Tolerance Degrees",
		"default_value": 4.0,
		"description": "Sets [member ScalableVectorShape2D.tolerance_degrees] for all imported shapes"
	},
	{
		"name": "Max Stages",
		"default_value": 5,
		"description": "Sets [member ScalableVectorShape2D.max_stages] for all imported shapes"
	}]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return !(
		(!options["Use Scalable Vector Shapes"] and option_name in ["Update Curves at runtime","Tolerance Degrees","Max Stages"]) or 
		((!options["Antialiased"] or !options["Use Line2D"]) and option_name == "Antialiased Line2D"))

func _can_import_threaded() -> bool:
	return true

func _get_preset_count() -> int:
	return 0

func _get_importer_name() -> String:
	return "ScaleableVectorShapes2d.svg"
