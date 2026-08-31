extends Node2D


func _ready():
	var imported_svg := SVGImporter.load_svg("res://addons/curved_lines_2d/tests/01-godot-icon.svg",{
		"import_as_svs": true,
		"lock_shapes": true,
		"antialiased_shapes": false,
		"import_stroke_as_line_2d": true,
		"collision_object_type": ScalableVectorShape2D.CollisionObjectType.NONE,
		"update_curve_at_runtime": true,
		"resource_local_to_scene": true,
		"tolerance_degrees": 4.0,
		"max_stages": 5,
		"use_antialiased_line_2d": false
	},func(msg, log_level): if log_level > SVGImporter.LogLevel.INFO: print(msg))
	add_child(imported_svg)
	var eye_white : ScalableVectorShape2D = imported_svg.get_node("Group").get_node("Circle2")
	var pupil : ScalableVectorShape2D = imported_svg.get_node("Group2").get_node("Circle")
	eye_white.use_interect_when_clipping = true
	pupil.clip_paths = [eye_white]
	get_tree().create_tween().tween_property(eye_white, "size:y", 10.0, 1.0)
