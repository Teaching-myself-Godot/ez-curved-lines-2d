extends Node2D

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
	new_shape.collision_object = StaticBody2D.new()
	new_shape.add_to_group("blocks")
	new_shape.add_child(new_shape.collision_object)
	new_shape.add_child(new_shape.polygon)
	add_child(new_shape)


func _on_rat_cut_shapes(global_pos: Vector2, curve: Curve2D) -> void:
	var new_shape = ScalableVectorShape2D.new()
	new_shape.update_curve_at_runtime = true
	new_shape.curve = curve
	new_shape.position = global_pos
	add_child(new_shape)
	for block in get_tree().get_nodes_in_group("blocks"):
		if Rect2(new_shape.position, new_shape.get_bounding_rect().size).intersects(
			Rect2(block.position, block.get_bounding_rect().size)
		):
			(block as ScalableVectorShape2D).add_clip_path(new_shape)
