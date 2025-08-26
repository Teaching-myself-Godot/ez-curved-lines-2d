extends Node2D

var collision_polygon_map : Dictionary[ScalableVectorShape2D, Array] = {}
var TheFinishScene : PackedScene = preload("res://addons/curved_lines_2d/examples/rat/the_finish.tscn")

func _ready() -> void:
	_set_finish()
	$Rat.has_won.connect(_set_finish)


func _set_finish() -> void:
	var cheese_spawns := $CheeseSpawns.get_children()
	var finish = TheFinishScene.instantiate()
	cheese_spawns[randi() % cheese_spawns.size()].add_child(finish)
	$Rat.finish = finish

func _on_drop_zone_body_entered(body: Node2D) -> void:
	if 'die' in body:
		body.die()


func _on_rat_place_shape(global_pos: Vector2, curve: Curve2D) -> void:
	var new_shape = ScalableVectorShape2D.new()
	new_shape.update_curve_at_runtime = true
	new_shape.curve = curve
	new_shape.position = global_pos
	new_shape.polygon = Polygon2D.new()
	new_shape.polygon.color = Color(0.402, 0.207, 0.0)
	new_shape.polygon.texture = NoiseTexture2D.new()
	(new_shape.polygon.texture as NoiseTexture2D).noise = FastNoiseLite.new()
	(new_shape.polygon.texture as NoiseTexture2D).seamless = true
	new_shape.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	new_shape.add_to_group("blocks")
	new_shape.add_child(new_shape.polygon)
	new_shape.polygons_updated.connect(_add_collision_polygons)
	add_child(new_shape)


func _on_rat_cut_shapes(global_pos: Vector2, curve: Curve2D) -> void:
	var new_shape = ScalableVectorShape2D.new()
	new_shape.update_curve_at_runtime = true
	new_shape.curve = curve
	new_shape.position = global_pos
	add_child(new_shape)
	for block in get_tree().get_nodes_in_group("blocks"):
		if Rect2(new_shape.position, new_shape.get_bounding_rect().size).intersects(
			Rect2(block.position, block.get_bounding_rect().size), true
		):
			(block as ScalableVectorShape2D).add_clip_path(new_shape)


func _add_collision_polygons(polygons : Array[PackedVector2Array], _poly_strokes : Array[PackedVector2Array], svs : ScalableVectorShape2D):
	if svs in collision_polygon_map:
		for old_poly : Node in collision_polygon_map.get(svs):
			old_poly.queue_free()
		collision_polygon_map.get(svs).clear()
	else:
		collision_polygon_map[svs] = []
	for poly in polygons:
		var col_poly := CollisionPolygon2D.new()
		col_poly.transform = svs.transform
		col_poly.polygon = poly
		collision_polygon_map[svs].append(col_poly)
		%BlockStaticBody2D.add_child(col_poly)
