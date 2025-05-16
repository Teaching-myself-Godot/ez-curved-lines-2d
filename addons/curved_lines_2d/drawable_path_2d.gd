@tool
extends Path2D
## A custom node that extends Path2D so it can be drawn as a Line2D
## Original adapted code: https://www.hedberggames.com/blog/rendering-curves-in-godot
## @deprecated: Use [ScalableVectorShape2D] instead.
class_name  DrawablePath2D

## Emitted when a new set of points was calculated for a connected Line2D, Polygon2D, or CollisionPolygon2D
signal path_changed(new_points : PackedVector2Array)

## This signal is used internally in editor-mode to tell the DrawablePath2D tool that
## the instance of assigned Line2D, Polygon2D, or CollisionPolygon2D has changed
signal assigned_node_changed()


## The Polygon2D controlled by this Path2D
@export var polygon: Polygon2D:
	set(_poly):
		polygon = _poly
		assigned_node_changed.emit()

## The Line2D controlled by this Path2D
@export var line: Line2D:
	set(_line):
		line = _line
		assigned_node_changed.emit()

## The CollisionPolygon2D controlled by this Path2D
@export var collision_polygon: CollisionPolygon2D:
	set(_poly):
		collision_polygon = _poly
		assigned_node_changed.emit()

## Controls whether the path is treated as static (only update in editor) or dynamic (can be updated during runtime)
## If you set this to true, be alert for potential performance issues
@export var update_curve_at_runtime: bool = false

## Controls the paramaters used to divide up the line  in segments.
## These settings are prefilled with the default values.
@export_group("Tesselation settings")
## Controls how many subdivisions a curve segment may face before it is considered approximate enough.
## Each subdivision splits the segment in half, so the default 5 stages may mean up to 32 subdivisions
## per curve segment. Increase with care!
@export_range(1, 10) var max_stages : int = 5:
	set(_max_stages):
		max_stages = _max_stages
		assigned_node_changed.emit()
## Controls how many degrees the midpoint of a segment may deviate from the real curve, before the
## segment has to be subdivided.
@export_range(0.0, 180.0) var tolerance_degrees := 4.0:
	set(_tolerance_degrees):
		tolerance_degrees = _tolerance_degrees
		assigned_node_changed.emit()

var lock_assigned_shapes := true

# Wire up signals at runtime
func _ready():
	if update_curve_at_runtime:
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)


# Wire up signals on enter tree for the editor
func _enter_tree():
	if Engine.is_editor_hint():
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)
		if not assigned_node_changed.is_connected(_on_assigned_node_changed):
			assigned_node_changed.connect(_on_assigned_node_changed)
	# handles update when reparenting
	if update_curve_at_runtime:
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)


# Clean up signals (ie. when closing scene) to prevent error messages in the editor
func _exit_tree():
	if curve.changed.is_connected(curve_changed):
		curve.changed.disconnect(curve_changed)


func _on_assigned_node_changed():
	if is_instance_valid(line):
		if lock_assigned_shapes:
			line.set_meta("_edit_lock_", true)
		curve_changed()
	if is_instance_valid(polygon):
		if lock_assigned_shapes:
			polygon.set_meta("_edit_lock_", true)
		curve_changed()
	if is_instance_valid(collision_polygon):
		if lock_assigned_shapes:
			collision_polygon.set_meta("_edit_lock_", true)
		curve_changed()


# Redraw the line based on the new curve, using its tesselate method
func curve_changed():
	if (not is_instance_valid(line) and not is_instance_valid(polygon)
			and not is_instance_valid(collision_polygon)
			and not path_changed.has_connections()):
		# guard against needlessly invoking expensive tesselate operation
		return

	var new_points := curve.tessellate(max_stages, tolerance_degrees)
	# Fixes cases start- and end-node are so close to each other that
	# polygons won't fill and closed lines won't cap nicely
	if new_points[0].distance_to(new_points[new_points.size()-1]) < 0.001:
		new_points.remove_at(new_points.size() - 1)
	if is_instance_valid(line):
		line.points = new_points
	if is_instance_valid(polygon):
		polygon.polygon = new_points
	if is_instance_valid(collision_polygon):
		collision_polygon.polygon = new_points
	path_changed.emit(new_points)


func get_bounding_rect() -> Rect2:
	var points := curve.tessellate(max_stages, tolerance_degrees)
	if points.size() < 1:
		# Cannot calculate a center for 0 points
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var minx := INF
	var miny := INF
	var maxx := -INF
	var maxy := -INF
	for p : Vector2 in points:
		minx = p.x if p.x < minx else minx
		miny = p.y if p.y < miny else miny
		maxx = p.x if p.x > maxx else maxx
		maxy = p.y if p.y > maxy else maxy
	return Rect2(minx, miny, maxx - minx, maxy - miny)


func set_position_to_center() -> void:
	var c = get_bounding_rect().get_center()
	position += c
	for i in range(curve.get_point_count()):
		curve.set_point_position(i, curve.get_point_position(i) - c)
