extends Node2D

@onready var net := $Stick/NetRing/Net

var _net_point_pos_orig := Vector2.ZERO
var _net_angle : float = 0.0
var _net_length : float = 0.0
var _net_curve_handle_pos_orig := Vector2.ZERO
var _net_out_curve_handle_pos_orig := Vector2.ZERO
var _prev_rotation : float = 0.0


func _ready() -> void:
	var net_curve : Curve2D = net.curve
	_prev_rotation = global_rotation
	_net_point_pos_orig = net_curve.get_point_position(1)
	_net_out_curve_handle_pos_orig = net_curve.get_point_out(0)
	_net_angle = _net_point_pos_orig.angle()
	_net_length = _net_point_pos_orig.length()
	_net_curve_handle_pos_orig =  net_curve.get_point_in(1)


func _physics_process(_delta: float) -> void:
	if global_scale.y < 0:
		net.scale.y = -1
	else:
		net.scale.y = 1

	if global_rotation != _prev_rotation:
		_handle_in_motion()
	else:
		_handle_stationary()
	_prev_rotation = global_rotation


func _handle_in_motion():
	var rotation_delta : float = global_rotation - _prev_rotation
	if rotation_delta < -PI:
		rotation_delta += PI * 2
	elif rotation_delta > PI:
		rotation_delta -= PI * 2

	var target_net_cap_position := (
			_net_point_pos_orig if rotation_delta < 0.0 else
			_net_point_pos_orig * Vector2(1, -1)
	)
	var net_curve_handle_position := (
			_net_curve_handle_pos_orig if rotation_delta < 0.0 else
			_net_curve_handle_pos_orig * Vector2(1, -1)
	)
	_handle_update(target_net_cap_position, net_curve_handle_position, rotation_delta < 0.0)


func _handle_stationary():
	var target_angle = -global_rotation
	if target_angle > PI * 0.5 and target_angle < 1.92: # 110 degrees
		target_angle = 1.92
	elif target_angle < PI * 0.5 and target_angle > 1.22: # 70 degrees
		target_angle = 1.22
	var target_net_cap_position := _net_point_pos_orig.rotated(target_angle)
	var net_point_pos_delta := _net_point_pos_orig - target_net_cap_position
	var net_curve_handle_position := (
			_net_curve_handle_pos_orig + net_point_pos_delta if target_net_cap_position.y > 0.0 else
			_net_curve_handle_pos_orig + net_point_pos_delta - ((_net_point_pos_orig + _net_curve_handle_pos_orig) * 2)
	)
	_handle_update(target_net_cap_position, net_curve_handle_position, target_net_cap_position.y > 0.0)


func _handle_update(target_net_cap_position : Vector2, net_curve_handle_position : Vector2, flip_in  : bool):
	var net_curve : Curve2D = net.curve
	if target_net_cap_position == net_curve.get_point_position(1) and net_curve_handle_position == net_curve.get_point_in(1):
		return

	net_curve.set_point_position(1, net_curve.get_point_position(1).move_toward(target_net_cap_position, 15))
	net_curve.set_point_in(1, net_curve.get_point_in(1).move_toward(net_curve_handle_position, 15))

	if flip_in:
		net_curve.set_point_out(0, _net_out_curve_handle_pos_orig)
	else:
		net_curve.set_point_out(0, -_net_out_curve_handle_pos_orig)

