extends Sprite3D

@export var my_viewport : SubViewport

var my_node_2d : Node2D
var base_node_scale : Vector2
var base_viewport_dimensions : Vector2
var my_base_pixel_size : float

func _ready() -> void:
	if is_instance_valid(my_viewport):
		my_node_2d = my_viewport.get_child(0)
		base_node_scale = my_node_2d.scale
		base_viewport_dimensions = my_viewport.size
		my_base_pixel_size = pixel_size


func _process(delta: float) -> void:
	var distance_to_cam := global_position.distance_to(get_viewport().get_camera_3d().global_position)
	$Label.text = """
		distance to camera: %f
		node 2d scale: %s
		my viewport size: %s
	""" % [distance_to_cam,
		str(my_node_2d.scale),
		str(my_viewport.size)
	]
	if distance_to_cam < 0.5:
		my_node_2d.scale = base_node_scale * 16.0
		my_viewport.size = base_viewport_dimensions * 16.0
		pixel_size = my_base_pixel_size * 0.06125
	elif distance_to_cam < 1.0:
		my_node_2d.scale = base_node_scale * 8.0
		my_viewport.size = base_viewport_dimensions * 8.0
		pixel_size = my_base_pixel_size * 0.125
	elif distance_to_cam < 4.0:
		my_node_2d.scale = base_node_scale * 4.0
		my_viewport.size = base_viewport_dimensions * 4.0
		pixel_size = my_base_pixel_size * 0.25
	elif distance_to_cam < 8.0:
		my_node_2d.scale = base_node_scale * 2.0
		my_viewport.size = base_viewport_dimensions * 2.0
		pixel_size = my_base_pixel_size * 0.5
	else:
		my_node_2d.scale = base_node_scale
		my_viewport.size = base_viewport_dimensions
		pixel_size = my_base_pixel_size
