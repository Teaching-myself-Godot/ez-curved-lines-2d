@tool
extends Node2D

class_name DynamicOutline2D

## [Color] of the ouline to draw
@export var stroke_color := Color.WHITE:
	set(new_color):
		stroke_color = new_color
		queue_redraw()

## Thickness of the outline to draw
@export var stroke_width := 10.0:
	set(new_width):
		stroke_width = new_width
		queue_redraw()

## Apply basic antialiasing (via [method CanvasItem.draw_polyline] function)
@export var antialiased := false:
	set(new_aa):
		antialiased = new_aa
		queue_redraw()

## List of [ScalableVectorShape2D]'s to draw outlines around
@export var shapes : Array[ScalableVectorShape2D]: set = _on_shapes_assigned

func _enter_tree() -> void:
	set_meta("_edit_lock_", true)


func _on_shapes_assigned(new_shapes : Array[ScalableVectorShape2D]) -> void:
	for svs : ScalableVectorShape2D in shapes:
		if not is_instance_valid(svs):
			continue
		if svs not in shapes:
			if svs.path_changed.is_connected(_on_path_changed):
				svs.path_changed.disconnect(_on_path_changed)
			if svs.transform_changed.is_connected(_on_path_changed):
				svs.transform_changed.disconnect(_on_path_changed)
	for svs : ScalableVectorShape2D in new_shapes:
		if not is_instance_valid(svs):
			continue
		if not svs.path_changed.is_connected(_on_path_changed):
			svs.path_changed.connect(_on_path_changed)
		if not svs.transform_changed.is_connected(_on_path_changed):
			svs.set_notify_transform(true)
			svs.transform_changed.connect(_on_path_changed)
	shapes = new_shapes
	queue_redraw()


func _on_path_changed(_new_points = null) -> void:
	queue_redraw()


func _draw() -> void:
	var shape_polygons := Array(shapes.filter(func(s): return s is ScalableVectorShape2D)
			.map(func(s : ScalableVectorShape2D): return Array(s.tessellate()).map(func(p): return s.to_global(p))
		), TYPE_PACKED_VECTOR2_ARRAY, "", null)
	if shape_polygons.is_empty():
		return
	var result := Geometry2DUtil.calculate_outlines(shape_polygons)
	for poly in result:
		poly.append(poly[0])
		draw_polyline(poly, stroke_color, stroke_width, antialiased)

