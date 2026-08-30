@tool
extends Node2D
## This tool node holds the information needed to keep its child-nodes
## resulting from an import via [SVGImporter] synchronized with changes
## to its source svg file.
##
## Because it is managed by the [CurvedLines2D] editor plugin code, sync
## will only start when triggered via the Import SVG File Tab, or, when
## created manually, by saving and reopening your scene
class_name SyncedSVGRoot

signal resources_changed(resource_paths : PackedStringArray)

@export var svg_resource_path : String

@export var is_svs := true:
	set(x): is_svs = x; _on_property_changed()
@export var is_lock := true:
	set(x): is_lock = x; _on_property_changed()
@export var is_aa := false:
	set(x): is_aa = x; _on_property_changed()
@export var is_line_2d := true:
	set(x): is_line_2d = x; _on_property_changed()
@export var coll_type := ScalableVectorShape2D.CollisionObjectType.NONE:
	set(x): coll_type = x; _on_property_changed()
@export var is_update_curve_at_runtime := true:
	set(x): is_update_curve_at_runtime = x; _on_property_changed()
@export var is_resource_local_to_scene := true:
	set(x): is_resource_local_to_scene = x; _on_property_changed()
@export var tol_deg := 4.0:
	set(x): tol_deg = x; _on_property_changed()
@export var max_stg := 5:
	set(x): max_stg = x; _on_property_changed()
@export var using_antialiased_line_2d := false:
	set(x): using_antialiased_line_2d = x; _on_property_changed()


func _on_property_changed() -> void:
	if Engine.is_editor_hint():
		set_meta("_checksum", "invalidated")
		resources_changed.emit([svg_resource_path])
