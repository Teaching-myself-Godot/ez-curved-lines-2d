extends Node2D

var block_to_collision_poly_map : Dictionary[ScalableVectorShape2D, Array] = {}

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
	new_shape.render_complete.connect(func(result): _update_collision_polygons(new_shape, result))
	add_child(new_shape)


func _on_rat_cut_shapes(global_pos: Vector2, curve: Curve2D) -> void:
	var new_shape = ScalableVectorShape2D.new()
	new_shape.update_curve_at_runtime = true
	new_shape.curve = curve
	new_shape.position = global_pos
	var clicked_on_blocks = get_tree().get_nodes_in_group("blocks").filter(func(block : ScalableVectorShape2D): return block.get_bounding_rect().intersects(new_shape.get_bounding_rect()))
	if clicked_on_blocks.is_empty():
		return

	add_child(new_shape)
	for block : ScalableVectorShape2D in clicked_on_blocks:
		for old_block : CollisionPolygon2D in block_to_collision_poly_map[block]:
			old_block.queue_free()

		block.add_clip_path(new_shape)


func _update_collision_polygons(block : ScalableVectorShape2D, polies) -> void:
	if block not in block_to_collision_poly_map:
		block_to_collision_poly_map[block] = []
	block_to_collision_poly_map[block].clear()
	for poly in polies:
		var new_collision_polygon_2d := CollisionPolygon2D.new()
		new_collision_polygon_2d.name ="Testing"
		new_collision_polygon_2d.position = block.position
		new_collision_polygon_2d.polygon = poly
		%BlockStaticBody2D.add_child(new_collision_polygon_2d)
		block_to_collision_poly_map[block].append(new_collision_polygon_2d)
