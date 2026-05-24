@tool
extends Object
class_name ClosestPointOnCurveMeta
var before_segment : int
var point_position : Vector2
var local_point_position : Vector2
var segment_rotation : float


func _init(bs : int = 0, pp := Vector2.ZERO , lpp := Vector2.ZERO, segr := 0.0):
	before_segment = bs
	point_position = pp
	local_point_position = lpp
	segment_rotation = segr

func _to_string() -> String:
	return (
		"ClosestPointOnCurveMeta(before_segment: " +  str(before_segment) +
		", point_position: " + str(point_position) +
		", local_point_position: " + str(local_point_position) +
		", segment_rotation: " + str(segment_rotation) +
		")"
	)
