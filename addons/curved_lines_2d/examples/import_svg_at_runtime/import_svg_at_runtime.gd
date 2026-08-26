extends Node2D


func _ready():
	var node := await SVGImporter.new(
		true, true, false, true, ScalableVectorShape2D.CollisionObjectType.NONE,
		true, true, 4.0, 5, false,
		SVGImporter.get_runtime_handler(), print
	).load_svg("res://addons/curved_lines_2d/tests/01-godot-icon.svg", self, [])
	var eye_white : ScalableVectorShape2D = find_child("Group").find_child("Circle2")
	var pupil : ScalableVectorShape2D = find_child("Group2").find_child("Circle")
	eye_white.use_interect_when_clipping = true
	pupil.clip_paths = [eye_white]
	get_tree().create_tween().tween_property(eye_white, "size:y", 10.0, 1.0)
