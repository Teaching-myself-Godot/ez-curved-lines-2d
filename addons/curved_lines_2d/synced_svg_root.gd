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

## Emitted in edit mode when any setting changes in this node
signal resources_changed(resource_paths : PackedStringArray)

## Path to the SVG file to keep child nodes synchronized with
@export var svg_resource_path : String:
	set(x): svg_resource_path = x; _on_property_changed()
## If true, import shapes nodes as [ScalableVectorShape2D] that manages godot native nodes via
## [member ScalableVectorShape2D.line], [member ScalableVectorShape2D.polygon],
## [member ScalableVectorShape2D.collision_object] and [member ScalableVectorShape2D.polystroke]
## If false, import only [Polygon2D], [Line2D] and [CollisionPolygon2D], unmanaged by [ScalableVectorShape2D]
@export var is_svs := true:
	set(x): is_svs = x; _on_property_changed()
## If true, lock the assigned [Polygon2D], [Line2D] and [Polygon2D] nodes in the editor
@export var is_lock := true:
	set(x): is_lock = x; _on_property_changed()
## If true, mark all the Node2D that come from SVG <g> tags a group in Godot as well.
## Do the same for ScalableVectorShape2D.
@export var mark_groups := false:
	set(x): mark_groups = x; _on_property_changed()
## If true, flag on the antialiased field for [Line2D] and [Polygon2D]
@export var is_aa := false:
	set(x): is_aa = x; _on_property_changed()
## If true, import SVG Strokes as [Line2D], assigning [member ScalableVectorShape2D.line]
## if false import SVG Strokes as [Polygon2D], assigning [member ScalableVectorShape2D.poly_stroke]
@export var is_line_2d := true:
	set(x): is_line_2d = x; _on_property_changed()
## The type of [CollisionObject2D] to wrap around [CollisionPolygon2D] nodes managed by
## [member ScalableVectorShape2D.collision_object]
@export var coll_type := ScalableVectorShape2D.CollisionObjectType.NONE:
	set(x): coll_type = x; _on_property_changed()
## Sets [member ScalableVectorShape2D.update_curve_at_runtime] for all imported shapes
@export var is_update_curve_at_runtime := true:
	set(x): is_update_curve_at_runtime = x; _on_property_changed()
## Sets [member Curve2D.resource_local_to_scene] for  [member ScalableVectorShape2D.curve]
## and for [member ScalableVectorShape2D.arc_list]
@export var is_resource_local_to_scene := true:
	set(x): is_resource_local_to_scene = x; _on_property_changed()
## Sets [member ScalableVectorShape2D.tolerance_degrees] for all imported shapes
@export var tol_deg := 4.0:
	set(x): tol_deg = x; _on_property_changed()
## Sets [member ScalableVectorShape2D.max_stages] for all imported shapes
@export var max_stg := 5:
	set(x): max_stg = x; _on_property_changed()
## Sets [member Line2D.texture] to a blurred texture, with repeat.
@export var using_antialiased_line_2d := false:
	set(x): using_antialiased_line_2d = x; _on_property_changed()


func _on_property_changed() -> void:
	if Engine.is_editor_hint():
		set_meta("_checksum", "invalidated")
		resources_changed.emit([svg_resource_path])
