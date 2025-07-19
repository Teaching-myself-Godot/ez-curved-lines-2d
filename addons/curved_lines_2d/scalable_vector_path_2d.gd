@tool
class_name ScalableVectorPath2D
extends Resource


@export var curve: Curve2D = Curve2D.new():
	set(_curve):
		curve = _curve if _curve != null else Curve2D.new()
		if not curve.changed.is_connected(emit_changed):
			curve.changed.connect(emit_changed)
		emit_changed()


@export var arc_list : ScalableArcList = ScalableArcList.new():
	set(_arc_list):
		arc_list = _arc_list if _arc_list != null else ScalableArcList.new()
		if not arc_list.changed.is_connected(emit_changed):
			arc_list.changed.connect(emit_changed)
		emit_changed()


func _init(c := Curve2D.new(), a := ScalableArcList.new()) -> void:
	curve = c
	arc_list = a
