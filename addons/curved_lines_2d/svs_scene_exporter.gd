@tool
extends Object
class_name SVSSceneExporter


static func export_image(export_root_node : Node, stored_box_ref : Dictionary[String, Vector2] = {},
		render_parent := Node.new(), forward_aa := true) -> Image:
	var sub_viewport := SubViewport.new()
	render_parent.add_child(sub_viewport)
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var copied : Node = export_root_node.duplicate()
	sub_viewport.add_child(copied)
	var box = copied.get_bounding_box() if copied is ScalableVectorShape2D else [Vector2.ZERO]
	var child_list := copied.get_children()
	var min_x = box.map(func(corner): return corner.x).min()
	var min_y = box.map(func(corner): return corner.y).min()
	var max_x = box.map(func(corner): return corner.x).max()
	var max_y = box.map(func(corner): return corner.y).max()

	while child_list.size() > 0:
		var child : Node = child_list.pop_back()
		if child is Camera2D:
			child.enabled = false
		child_list.append_array(child.get_children())
		if child is ScalableVectorShape2D:
			var box1 = child.get_bounding_box()
			var min_x1 = box1.map(func(corner): return corner.x).min()
			var min_y1 = box1.map(func(corner): return corner.y).min()
			var max_x1 = box1.map(func(corner): return corner.x).max()
			var max_y1 = box1.map(func(corner): return corner.y).max()
			min_x = floori(min_x if min_x1 > min_x else min_x1)
			min_y = floori(min_y if min_y1 > min_y else min_y1)
			max_x = ceili(max_x if max_x1 < max_x else max_x1)
			max_y = ceili(max_y if max_y1 < max_y else max_y1)
	sub_viewport.canvas_transform.origin = -Vector2(min_x, min_y)
	sub_viewport.size = Vector2(max_x, max_y) - Vector2(min_x, min_y)
	if forward_aa:
		sub_viewport.msaa_2d = Viewport.MSAA_8X
	else:
		sub_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

	stored_box_ref["tl"] = Vector2(min_x, min_y)
	stored_box_ref["br"] = Vector2(max_x, max_y)
	await RenderingServer.frame_post_draw
	var img = sub_viewport.get_texture().get_image()
	sub_viewport.queue_free()
	return img


static func export_sprite_frames(root_node : Node,
		animation_player : AnimationPlayer,
		anim_name : String, fps : int,
		render_parent : Node, on_progress : Callable,
		forward_aa := false) -> Array[Image]:
	var interval := 1.0 / fps
	animation_player.stop()
	animation_player.current_animation = anim_name
	animation_player.get_animation(anim_name)
	var boxes : Array[Dictionary] = []
	var images : Array[Image] = []
	var frame_count := ceili(animation_player.current_animation_length / interval)
	if on_progress:
		on_progress.call("Rendering animation %s at %d fps to %d frames" % [anim_name, fps, frame_count])
	# Render each frame into an image
	for idx in range(frame_count):
		var pos = idx * interval
		if pos > animation_player.current_animation_length:
			pos = animation_player.current_animation_length
		animation_player.seek(pos, true)
		animation_player.pause()
		var box : Dictionary[String, Vector2] = {}
		var im = await export_image(root_node, box, render_parent, forward_aa)
		boxes.append(box)
		images.append(im)
	animation_player.stop()

	# Determine the bounding box into which all the rendered images would fit
	var min_x = boxes.map(func(box): return box["tl"].x).min()
	var min_y = boxes.map(func(box): return box["tl"].y).min()
	var max_x = boxes.map(func(box): return box["br"].x).max()
	var max_y = boxes.map(func(box): return box["br"].y).max()
	var return_list : Array[Image] = []

	# rerender and realign the images such that they all have the same size
	for idx in images.size():
		var im : Image = Image.create_empty(ceili(max_x) - floori(min_x), ceili(max_y) - floor(min_y), false, images[idx].get_format())
		for x in images[idx].get_size().x:
			for y in images[idx].get_size().y:
				im.set_pixel(floori(boxes[idx]["tl"].x) - min_x + x, floori(boxes[idx]["tl"].y) - min_y + y, images[idx].get_pixel(x, y))
		return_list.append(im)
	return return_list
