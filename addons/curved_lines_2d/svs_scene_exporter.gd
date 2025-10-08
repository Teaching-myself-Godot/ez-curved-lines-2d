@tool
extends Object
class_name SVSSceneExporter


static func export_image(export_root_node : Node, stored_box : Dictionary[String, Vector2] = {}, render_parent := Node.new()) -> Image:
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
	sub_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	sub_viewport.msaa_2d = Viewport.MSAA_8X
	stored_box["tl"] = Vector2(min_x, min_y)
	stored_box["br"] = Vector2(max_x, max_y)
	await RenderingServer.frame_post_draw
	var img = sub_viewport.get_texture().get_image()
	sub_viewport.queue_free()
	return img


