@tool
extends Node2D
## A custom node that uses a Curve2D to control shapes like Line2D, Polygon2D with
## Original adapted code: https://www.hedberggames.com/blog/rendering-curves-in-godot
class_name ScalableVectorShape2D

## Emitted when a new set of points was calculated for the [member curve].
signal path_changed(new_points : PackedVector2Array)

## This signal is used internally in editor-mode to tell the DrawablePath2D tool that
## the instance of assigned [member line], [member polygon], or [member collision_polygon] has changed.
signal assigned_node_changed()

## This signal is emitted when the properties for describing an ellipse or rectangle change.
## Further reading: [member shape_type]
signal dimensions_changed()

## The constant used to convert a radius unit to the equivalent cubic Beziér control point length
const R_TO_CP = 0.5523


enum ShapeType {
	## Gives every point in the [member curve] a handle, as well as their in- and out- control points.
	## Ignores the [member size], [member offset], [member rx] and [member ry] properties when
	## drawing the shape.
	PATH,
	## Keeps the shape of the [member curve] as a rectangle, based on the [member offset],
	## [member size], [member rx] and [member ry].
	## Provides one handle to change [member size],	and two handles to change [member rx] and
	## [member ry] for rounded corners.
	## The [member offset] can change by using the pivot-tool in the 2D Editor
	RECT,
	## Keeps the shape of the [member curve] as an ellipse, based on the [member offset] and
	## [member size]
	## Provides one handle to change [member size]. The [member size] determines the radii of the
	## ellipse on the y- and x- axis, so [member rx] and [member ry] are always sync'ed with
	## [member size] (and vice-versa)
		## The [member offset] can change by using the pivot-tool in the 2D Editor
	ELLIPSE
}

## Controls the paramaters used to divide up the line  in segments.
## These settings are prefilled with the default values.
@export_group("Curve settings")
## The [Curve2D] that dynamically triggers updates of the shapes assigned to this node
## Changes to this curve will also emit the path_changed signal with the updated points array
@export var curve: Curve2D = Curve2D.new():
	set(_curve):
		curve = _curve
		assigned_node_changed.emit()

## Controls whether the path is treated as static (only update in editor) or dynamic (can be updated during runtime)
## If you set this to true, be alert for potential performance issues
@export var update_curve_at_runtime: bool = false

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

@export_group("Fill")
## The 'Fill' of a [ScalableVectorShape2D] is simply an instance of a [Polygon2D] node
## assigned to the `polygon` property.
## If you remove that [Polygon2D] node, you need to unassign it here as well, before
## you can add a new 'Fill' with the 'Add Fill' button
## The polygon's shape is controlled by this node's curve ([Curve2D]) property,
## it does _not_ have to be the child of this ScalableVectorShape2D
@export var polygon: Polygon2D:
	set(_poly):
		polygon = _poly
		assigned_node_changed.emit()

@export_group("Stroke")
## The 'Stroke' of a [ScalableVectorShape2D] is simply an instance of a [Line2D] node
## assigned to the `line` property.
## If you remove that Line2D node, you need to unassign it here as well, before
## you can add a new 'Stroke' with the 'Add Stroke' button
## The line's shape is controlled by this node's curve ([Curve2D]) pproperty, it
## does _not_ have to be the child of this [ScalableVectorShape2D]
@export var line: Line2D:
	set(_line):
		line = _line
		assigned_node_changed.emit()

@export_group("Collision Polygon")
## The CollisionPolygon2D controlled by this node's curve property
@export var collision_polygon: CollisionPolygon2D:
	set(_poly):
		collision_polygon = _poly
		assigned_node_changed.emit()

@export_group("Shape Type Settings")
## Determines what handles are shown in the editor and how the [member curve] is (re)drawn on changing
## properties [member size], [member offset], [member rx], and [member ry].
@export var shape_type := ShapeType.PATH:
	set(st):
		shape_type = st
		if st == ShapeType.PATH:
			assigned_node_changed.emit()
		else:
			if shape_type == ShapeType.RECT:
				rx = 0.0
				ry = 0.0
			dimensions_changed.emit()

@export var offset : Vector2 = Vector2(0.0, 0.0):
	set(ofs):
		offset = ofs
		dimensions_changed.emit()

@export var size : Vector2 = Vector2(100.0, 100.0):
	set(sz):
		if sz.x < 0:
			sz.x = 0.001
		if sz.y < 0:
			sz.y = 0.001
		if shape_type == ShapeType.RECT:
			if sz.x < rx * 2.001:
				sz.x = rx * 2.001
			if sz.y < ry * 2.001:
				sz.y = ry * 2.001
			size = sz
			dimensions_changed.emit()
		elif shape_type == ShapeType.ELLIPSE:
			size = sz
			rx = sz.x * 0.5
			ry = sz.y * 0.5

@export var rx : float = 0.0:
	set(_rx):
		rx = _rx if _rx > 0 else 0
		if shape_type == ShapeType.RECT:
			if rx > size.x * 0.49:
				rx = size.x * 0.49
		dimensions_changed.emit()

@export var ry : float = 0.0:
	set(_ry):
		ry = _ry if _ry > 0 else 0
		if shape_type == ShapeType.RECT:
			if ry > size.y * 0.49:
				ry = size.y * 0.49
		dimensions_changed.emit()

@export_group("Editor settings")
## The [Color] used to draw the this shape's curve in the editor
@export var shape_hint_color := Color.LIME_GREEN
## When this field is checked, the 'Strokes', 'Fills' and 'Collisions' created
## with the 'Add ...' buttons will be locked from transforming to prevent
## inadvertently changing them, whilst the idea is that [ScalableVectorShape2D]
## controls them
@export var lock_assigned_shapes := true

# Wire up signals at runtime
func _ready():
	if update_curve_at_runtime:
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)
	if not dimensions_changed.is_connected(_on_dimensions_changed):
		dimensions_changed.connect(_on_dimensions_changed)


# Wire up signals on enter tree for the editor
func _enter_tree():
	# ensure forward compatibility by assigning the default ShapeType
	if shape_type == null:
		shape_type = ShapeType.PATH
	if Engine.is_editor_hint():
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)
		if not assigned_node_changed.is_connected(_on_assigned_node_changed):
			assigned_node_changed.connect(_on_assigned_node_changed)
	# handles update when reparenting
	if update_curve_at_runtime:
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)
	# updates the curve points when size, offset, rx, or ry prop changes
	# (used for ShapeType.RECT and ShapeType.ELLIPSE)
	if not dimensions_changed.is_connected(_on_dimensions_changed):
		dimensions_changed.connect(_on_dimensions_changed)
	_on_dimensions_changed()

# Clean up signals (ie. when closing scene) to prevent error messages in the editor
func _exit_tree():
	if curve.changed.is_connected(curve_changed):
		curve.changed.disconnect(curve_changed)


func _on_dimensions_changed():
	if shape_type == ShapeType.RECT:
		var width = size.x
		var height = size.y
		# curve is passed by reference to trigger changed on existing instance
		set_rect_points(curve, width, height, rx, ry, offset)
	elif shape_type == ShapeType.ELLIPSE:
		# curve is passed by reference to trigger changed on existing instance
		set_ellipse_points(curve, size, offset)


func _on_assigned_node_changed():
	if Engine.is_editor_hint() or update_curve_at_runtime:
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)

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


## Exposes assigned_node_changed signal to outside callers
func notify_assigned_node_change():
	assigned_node_changed.emit()


## Redraw the line based on the new curve, using its tesselate method
func curve_changed():
	if (not is_instance_valid(line) and not is_instance_valid(polygon)
			and not is_instance_valid(collision_polygon)
			and not path_changed.has_connections()):
		# guard against needlessly invoking expensive tesselate operation
		return

	var new_points := curve.tessellate(max_stages, tolerance_degrees)
	# Fixes cases start- and end-node are so close to each other that
	# polygons won't fill and closed lines won't cap nicely
	if new_points.size() > 0 and new_points[0].distance_to(new_points[new_points.size()-1]) < 0.001:
		new_points.remove_at(new_points.size() - 1)
	if is_instance_valid(line):
		line.points = new_points
		line.closed = is_curve_closed()
	if is_instance_valid(polygon):
		polygon.polygon = new_points
		if polygon.texture is GradientTexture2D:
			var box := get_bounding_rect()
			polygon.texture_offset = -box.position
			polygon.texture.width = 1 if box.size.x < 1 else box.size.x
			polygon.texture.height = 1 if box.size.y < 1 else box.size.y
	if is_instance_valid(collision_polygon):
		collision_polygon.polygon = new_points
	path_changed.emit(new_points)


## Calculate and return the bounding rect in local space
func get_bounding_rect() -> Rect2:
	if not curve:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
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


func has_point(global_pos : Vector2) -> bool:
	return get_bounding_rect().grow(
		line.width / 2.0 if is_instance_valid(line) else 0
	).has_point(to_local(global_pos))


func has_fine_point(global_pos : Vector2) -> bool:
	if is_instance_valid(polygon) or is_instance_valid(collision_polygon):
		var poly_points := curve.tessellate(max_stages, tolerance_degrees)
		return Geometry2D.is_point_in_polygon(to_local(global_pos), poly_points)
	return false


func set_position_to_center() -> void:
	var c = get_bounding_rect().get_center()
	position += c
	for i in range(curve.get_point_count()):
		curve.set_point_position(i, curve.get_point_position(i) - c)


func set_origin(global_pos : Vector2) -> void:
	var local_pos = to_local(global_pos)
	match shape_type:
		ShapeType.RECT, ShapeType.ELLIPSE:
			offset = offset - to_local(global_pos)
			global_position = global_pos
			if is_instance_valid(polygon) and polygon.texture is GradientTexture2D:
				polygon.texture_offset = -get_bounding_rect().position
		ShapeType.PATH, _:
			for i in range(curve.get_point_count()):
				curve.set_point_position(i, curve.get_point_position(i) - local_pos)
			global_position = global_pos
			if is_instance_valid(polygon) and polygon.texture is GradientTexture2D:
				polygon.texture_offset = -get_bounding_rect().position



func get_bounding_box() -> Array[Vector2]:
	var rect = get_bounding_rect().grow(
		line.width / 2.0 if is_instance_valid(line) else 0
	)
	return [
		to_global(rect.position),
		to_global(Vector2(rect.position.x + rect.size.x, rect.position.y)),
		to_global(rect.position + rect.size),
		to_global(Vector2(rect.position.x, rect.position.y  + rect.size.y)),
		to_global(rect.position)
	]


func get_poly_points() -> Array:
	return Array(curve.tessellate(max_stages, tolerance_degrees)).map(to_global)


func get_farthest_point(from_local_pos := Vector2.ZERO) -> Vector2:
	var farthest_point = from_local_pos
	for p in curve.tessellate(max_stages, tolerance_degrees):
		if p.distance_to(from_local_pos) > farthest_point.distance_to(from_local_pos):
			farthest_point = p
	return farthest_point


func is_curve_closed() -> bool:
	var n = curve.point_count
	return n > 2 and curve.get_point_position(0).distance_to(curve.get_point_position(n - 1)) < 0.001


func get_curve_handles() -> Array:
	if shape_type == ShapeType.RECT or shape_type == ShapeType.ELLIPSE:
		var point_pos := size + get_bounding_rect().position
		var rx_handle := Vector2(rx, 0)
		var ry_handle := Vector2(0, ry)
		var top_left := offset + Vector2(-size.x, -size.y) * 0.5
		return [{
			"point_position": to_global(point_pos),
			"mirrored": true,
			"in": rx_handle,
			"out": ry_handle,
			"in_position": to_global(top_left + rx_handle),
			"out_position": to_global(top_left + ry_handle),
			"is_closed": ""
		}]


	var n = curve.point_count
	var is_closed := is_curve_closed()
	var result := []
	for i in range(n):
		var p = curve.get_point_position(i)
		var c_i = curve.get_point_in(i)
		var c_o = curve.get_point_out(i)
		if i == 0 and is_closed:
			c_i = curve.get_point_in(n - 1)
		elif i == n - 1 and is_closed:
			continue
		result.append({
			'point_position': to_global(p),
			'in': c_i,
			'out': c_o,
			'mirrored': c_i.length() and c_i.distance_to(-c_o) < 0.01,
			'in_position': to_global(p + c_i),
			'out_position': to_global(p + c_o),
			'is_closed': (" ∞ " + str(n - 1) if i == 0 and is_closed else "")
		})
	return result


func get_gradient_handles() -> Dictionary:
	if not (
		is_instance_valid(polygon) and polygon.texture is GradientTexture2D
	):
		return {}
	var gradient_tex : GradientTexture2D = polygon.texture
	var box := get_bounding_rect()
	var stop_colors = Array(
		gradient_tex.gradient.colors if gradient_tex.gradient.colors else [
			Color.WHITE, Color.BLACK
		]
	).map(func(gc): return gc * polygon.color)
	var stop_positions = Array(gradient_tex.gradient.offsets).map(
		func(offs): return (gradient_tex.fill_to - gradient_tex.fill_from) * offs
	).map(func(offs_p): return gradient_tex.fill_from + offs_p
	).map(func(offs_p1): return to_global((offs_p1 * box.size) + box.position))

	var result := {
		"fill_from": gradient_tex.fill_from,
		"fill_to": gradient_tex.fill_to,
		"fill_from_pos": to_global((gradient_tex.fill_from * box.size) + box.position),
		"fill_to_pos":  to_global((gradient_tex.fill_to * box.size) + box.position),
		"start_color": stop_colors[0] * polygon.color,
		"end_color": stop_colors[stop_colors.size() - 1] * polygon.color,
		"stop_positions": stop_positions,
		"stop_colors": stop_colors
	}

	return result


func set_global_curve_point_position(global_pos : Vector2, point_idx : int) -> void:
	if curve.point_count > point_idx:
		curve.set_point_position(point_idx, to_local(global_pos))


func set_global_curve_cp_in_position(global_pos : Vector2, point_idx : int) -> void:
	if curve.point_count > point_idx:
		curve.set_point_in(point_idx, to_local(global_pos) - curve.get_point_position(point_idx))


func set_global_curve_cp_out_position(global_pos : Vector2, point_idx : int) -> void:
	if curve.point_count > point_idx:
		curve.set_point_out(point_idx, to_local(global_pos) - curve.get_point_position(point_idx))


func replace_curve_points(curve_in : Curve2D) -> void:
	curve.clear_points()
	for i in range(curve_in.point_count):
		curve.add_point(curve_in.get_point_position(i),
				curve_in.get_point_in(i), curve_in.get_point_out(i))


func _get_closest_point_on_curve_segment(p : Vector2, segment_p1_idx : int) -> Vector2:
	var curve_segment := Curve2D.new()
	curve_segment.add_point(
		curve.get_point_position(segment_p1_idx),
		Vector2.ZERO,
		curve.get_point_out(segment_p1_idx)
	)
	var segment_p2_idx = (0 if segment_p1_idx == curve.point_count - 1
			else segment_p1_idx + 1)
	curve_segment.add_point(
		curve.get_point_position(segment_p2_idx),
		curve.get_point_in(segment_p2_idx)
	)
	var poly_points := curve_segment.tessellate(max_stages, tolerance_degrees)
	var closest_result := Vector2.INF
	for i in range(1, poly_points.size()):
		var p_a := poly_points[i - 1]
		var p_b := poly_points[i]
		var c_p := Geometry2D.get_closest_point_to_segment(p, p_a, p_b)
		if p.distance_to(c_p) < p.distance_to(closest_result):
			closest_result = c_p
	return closest_result


func get_closest_point_on_curve(global_pos : Vector2) -> Dictionary:
	var p := to_local(global_pos)
	if curve.point_count < 2:
		return {
			"local_point_position": p,
			"point_position": global_pos,
			"before_segment": 1
		}

	var closest_result := Vector2.INF
	var before_segment := 1
	for i in range(curve.point_count):
		var c_p := _get_closest_point_on_curve_segment(p, i)
		if p.distance_to(c_p) < p.distance_to(closest_result):
			closest_result = c_p
			before_segment = i + 1

	return {
		"local_point_position": closest_result,
		"point_position": to_global(closest_result),
		"before_segment": before_segment
	}

## Convert an existing [Curve2D] instance to a (rounded) rectangle.
## [param curve] is passed by reference so the curve's [signal Resource.changed]
## signal is emitted.
static func set_rect_points(curve : Curve2D, width : float, height : float, rx := 0.0, ry := 0.0,
		offset := Vector2.ZERO) -> void:
	curve.clear_points()
	var top_left := offset + Vector2(-width, -height) * 0.5
	var top_right := offset + Vector2(width, -height) * 0.5
	var bottom_right := offset + Vector2(width, height) * 0.5
	var bottom_left := offset + Vector2(-width, height) * 0.5
	if rx == 0 and ry == 0:
		curve.add_point(top_left)
		curve.add_point(top_right)
		curve.add_point(bottom_right)
		curve.add_point(bottom_left)
		curve.add_point(top_left)
	else:
		curve.add_point(top_left + Vector2(width - rx, 0), Vector2.ZERO, Vector2(rx * R_TO_CP, 0))
		curve.add_point(top_left + Vector2(width, ry), Vector2(0, -ry * R_TO_CP))
		curve.add_point(top_left + Vector2(width, height - ry), Vector2.ZERO, Vector2(0, ry * R_TO_CP))
		curve.add_point(top_left + Vector2(width - rx, height), Vector2(rx * R_TO_CP, 0))
		curve.add_point(top_left + Vector2(rx, height), Vector2.ZERO, Vector2(-rx * R_TO_CP, 0))
		curve.add_point(top_left + Vector2(0, height - ry), Vector2(0, ry * R_TO_CP))
		curve.add_point(top_left + Vector2(0, ry), Vector2.ZERO, Vector2(0, -ry *  R_TO_CP))
		curve.add_point(top_left + Vector2(rx, 0), Vector2(-rx * R_TO_CP, 0))
		curve.add_point(top_left + Vector2(width - rx, 0), Vector2.ZERO, Vector2(rx * R_TO_CP, 0))


## Convert an existing [Curve2D] instance to an ellipse.
## [param curve] is passed by reference so the curve's [signal Resource.changed]
## signal is emitted.
static func set_ellipse_points(curve : Curve2D, size: Vector2, offset := Vector2.ZERO):
	curve.clear_points()
	curve.add_point(offset + Vector2(size.x * 0.5, 0), Vector2.ZERO, Vector2(0, size.y * 0.5 * SvgImporterDock.R_TO_CP))
	curve.add_point(offset + Vector2(0, size.y * 0.5), Vector2(size.x * 0.5 * SvgImporterDock.R_TO_CP, 0), Vector2(-size.x * 0.5 * SvgImporterDock.R_TO_CP, 0))
	curve.add_point(offset + Vector2(-size.x * 0.5, 0), Vector2(0, size.y * 0.5 * SvgImporterDock.R_TO_CP), Vector2(0, -size.y * 0.5 * SvgImporterDock.R_TO_CP))
	curve.add_point(offset + Vector2(0, -size.y * 0.5), Vector2(-size.x * 0.5 * SvgImporterDock.R_TO_CP, 0), Vector2(size.x * 0.5 * SvgImporterDock.R_TO_CP, 0))
	curve.add_point(offset + Vector2(size.x * 0.5, 0), Vector2(0, -size.y * 0.5 * SvgImporterDock.R_TO_CP))
