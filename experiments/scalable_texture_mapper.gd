@tool
extends Node

class_name ScalableTextureMapper

@export var TextureScene : PackedScene:
	set(ts):
		if not is_inside_tree():
			return
		var should_update := TextureScene != ts
		TextureScene = ts
		if should_update:
			_on_scene_picked()
@export var smallest_size := Vector2(16.0, 16.0)
@export var smallest_scale := Vector2.ONE
@export var mipmaps := 8


func _on_scene_picked():
	if Engine.is_editor_hint():
		print(get_children())
		for vp in get_children():
			vp.queue_free()
			remove_child(vp)
		print(get_children())
		if TextureScene == null:
			return
		var s_node := smallest_scale
		var s_vp := smallest_size
		for i in mipmaps:
			var texture_node := TextureScene.instantiate()
			if not texture_node is Node2D:
				texture_node.queue_free()
				return
			var viewport := SubViewport.new()
			viewport.name = "SubViewport(%dx%d)" % [s_vp.x, s_vp.y]
			viewport.add_child(texture_node)
			(texture_node as Node2D).scale = s_node
			viewport.size = s_vp
			s_node *= 2
			s_vp *= 2
			viewport.transparent_bg = true
			add_child(viewport)
			#viewport.owner = EditorInterface.get_edited_scene_root()
			#texture_node.owner = EditorInterface.get_edited_scene_root()
