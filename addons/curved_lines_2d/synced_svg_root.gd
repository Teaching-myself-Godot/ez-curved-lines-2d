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

@export var svg_resource_path : String
@export var checksum : String

@export var is_svs := true
@export var is_lock := true
@export var is_aa := false
@export var is_line_2d := true
@export var coll_type := ScalableVectorShape2D.CollisionObjectType.NONE
@export var is_update_curve_at_runtime := true
@export var is_resource_local_to_scene := true
@export var tol_deg := 4.0
@export var max_stg := 5
@export var using_antialiased_line_2d := false
