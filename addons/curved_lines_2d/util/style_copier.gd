@tool
class_name StyleCopier extends Object


class StyleCopyBuffer:
	var valid := false
	var has_fill : bool
	var fill_color : Color
	var gradient : GradientTexture2D
	var has_stroke : bool
	var stroke_color : Color
	var stroke_width : float
	var width_curve : Curve
	var line_cap_begin : Line2D.LineCapMode
	var line_cap_end : Line2D.LineCapMode
	var line_join : Line2D.LineJointMode
	var stroke_extrusion : ScalableVectorShape2D.StrokeExtrusionDirection
	var use_line_2d : bool
	var collision_object_type : ScalableVectorShape2D.CollisionObjectType
	var paint_order : CurvedLines2D.PaintOrder


static var _copy_buffer = StyleCopyBuffer.new()

static func is_copy_key_pressed(event : InputEvent) -> bool:
	return (
			event is InputEventKey and
			(event as InputEventKey).keycode == KEY_C and
			(event as InputEventKey).is_command_or_control_pressed() and
			(event as InputEventKey).shift_pressed and
			(event as InputEventKey).pressed
	)


static func copy_style_to_buffer(svs : ScalableVectorShape2D) -> void:
	_copy_buffer.valid = true
	_copy_buffer.has_fill = is_instance_valid(svs.polygon)
	_copy_buffer.fill_color = svs.fill_color
	_copy_buffer.gradient = (
		svs.polygon.texture.duplicate(true)
			if is_instance_valid(svs.polygon) and svs.polygon.texture is GradientTexture2D else
		null
	)
	_copy_buffer.has_stroke = is_instance_valid(svs.poly_stroke) or is_instance_valid(svs.line)
	_copy_buffer.stroke_color = svs.stroke_color
	_copy_buffer.stroke_width = svs.stroke_width
	_copy_buffer.width_curve = svs.line.width_curve.duplicate(true) if is_instance_valid(svs.line) and svs.line.width_curve else null
	_copy_buffer.line_cap_begin = svs.begin_cap_mode
	_copy_buffer.line_cap_end = svs.end_cap_mode
	_copy_buffer.line_join = svs.line_joint_mode
	_copy_buffer.stroke_extrusion = svs.extrusion_direction
	_copy_buffer.use_line_2d = is_instance_valid(svs.line)
	_copy_buffer.collision_object_type = svs.get_collision_object_type()
	_copy_buffer.paint_order = SVSPropertySync.get_valid_orders(svs).pop_front()

	print("""TODO: copy these:
Fill Present = %s
Fill color = %s
Gradient Setting = %s
Stroke Present = %s
Stroke Color = %s
Stroke Width = %f
Stroke Width Curve = %s
Stroke Settings:
	Cap Begin = %s
	Cap End = %s
	Join = %s
	Align = %s
Line2D usage = %s
CollisionObject type = %s
Paint Order = %s
		""" % [
			_copy_buffer.has_fill,
			_copy_buffer.fill_color,
			_copy_buffer.gradient,
			_copy_buffer.has_stroke,
			_copy_buffer.stroke_color,
			_copy_buffer.stroke_width,
			_copy_buffer.width_curve,
			_copy_buffer.line_cap_begin,
			_copy_buffer.line_cap_end,
			_copy_buffer.line_join,
			_copy_buffer.stroke_extrusion,
			_copy_buffer.use_line_2d,
			_copy_buffer.collision_object_type,
			_copy_buffer.paint_order
		])

