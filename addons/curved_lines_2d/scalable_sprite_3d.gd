@tool
extends Sprite3D

class_name ScalableSprite3D

@export var texture_source : ScalableTextureMapper:
	set(ts):
		texture_source = ts
		on_texture_source_changed()

var top_left_anchor := Node3D.new()
var bottom_right_anchor := Node3D.new()
var current_texture_idx := 0

func _ready() -> void:
	if is_instance_valid(texture_source):
		var ptsd := texture_source.smallest_size * 0.5
		top_left_anchor.position.x = -ptsd.x * pixel_size
		top_left_anchor.position.y = -ptsd.y * pixel_size
		bottom_right_anchor.position.x = ptsd.x * pixel_size
		bottom_right_anchor.position.y = ptsd.y * pixel_size
		add_child(top_left_anchor)
		add_child(bottom_right_anchor)


func on_texture_source_changed():
	if Engine.is_editor_hint():
		if not texture:
			texture = ViewportTexture.new()
		texture.viewport_path = EditorInterface.get_edited_scene_root().get_path_to(texture_source.get_child(0))



func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		current_texture_idx += 1
		if current_texture_idx > texture_source.get_children().size() - 1:
			current_texture_idx = 0
		texture = texture_source.get_child(current_texture_idx).get_texture()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var active_cam := get_viewport().get_camera_3d()
	if not is_instance_valid(active_cam):
		return
	var current_sprite_diameter := (active_cam.unproject_position(top_left_anchor.global_position)
			.distance_to(active_cam.unproject_position(bottom_right_anchor.global_position))
	)
	var current_texture_diameter = Vector2.ZERO.distance_to((texture_source.get_child(current_texture_idx) as SubViewport).size)
	$Label.text = """
		unprojected_pos: %s
		my diameter: %f
		current texture diameter: %f
	""" % [
		str(get_viewport().get_camera_3d().unproject_position(global_position)),
		current_sprite_diameter,
		current_texture_diameter,
	]
	if current_sprite_diameter > current_texture_diameter and current_texture_idx < texture_source.get_children().size() - 1:
		current_texture_idx += 1
		pixel_size *= 0.5
		texture = texture_source.get_child(current_texture_idx).get_texture()
	elif current_sprite_diameter < current_texture_diameter * pixel_size and current_texture_idx > 0:
		current_texture_idx -= 1
		pixel_size *= 2.0
		texture = texture_source.get_child(current_texture_idx).get_texture()
