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
	var paint_order : CurvedLines2D.PaintOrder


static var _copy_buffer = StyleCopyBuffer.new()

static func is_copy_key_pressed(event : InputEvent) -> bool:
	return (
			event is InputEventKey and
			(event as InputEventKey).keycode == KEY_C and
			(event as InputEventKey).is_command_or_control_pressed() and
			(event as InputEventKey).alt_pressed and
			(event as InputEventKey).pressed
	)


static func is_paste_key_pressed(event : InputEvent) -> bool:
	return (
			event is InputEventKey and
			(event as InputEventKey).keycode == KEY_V and
			(event as InputEventKey).is_command_or_control_pressed() and
			(event as InputEventKey).alt_pressed and
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
	_copy_buffer.paint_order = SVSPropertySync.get_valid_orders(svs).pop_front()



static func paste_style_to_svs(svs : ScalableVectorShape2D, do_commit := true) -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not _copy_buffer.valid:
		return
	if not is_instance_valid(scene_root):
		return
	var undo_redo := EditorInterface.get_editor_undo_redo()
	if do_commit:
		undo_redo.create_action("Paste styles")


	if _copy_buffer.has_fill:
		var polygon := svs.polygon if is_instance_valid(svs.polygon) else Polygon2D.new()
		if not is_instance_valid(svs.polygon):
			polygon.name = "Fill"
			undo_redo.add_do_property(svs, 'polygon', polygon)
			undo_redo.add_do_method(svs, 'add_child', polygon, true)
			undo_redo.add_do_method(polygon, 'set_owner', scene_root)
			undo_redo.add_undo_reference(polygon)
			undo_redo.add_undo_property(svs, 'polygon', null)
			undo_redo.add_undo_method(svs, 'remove_child', polygon)
		undo_redo.add_do_property(polygon, 'texture', _copy_buffer.gradient)
		undo_redo.add_undo_property(polygon, 'texture', polygon.texture)
	else:
		if is_instance_valid(svs.polygon):
			var polygon_2d := svs.polygon
			undo_redo.add_do_method(svs, 'remove_child', polygon_2d)
			undo_redo.add_do_property(svs, 'polygon', null)
			undo_redo.add_undo_method(svs, 'add_child', polygon_2d, true)
			undo_redo.add_undo_method(polygon_2d, 'set_owner', EditorInterface.get_edited_scene_root())
			undo_redo.add_undo_reference(polygon_2d)
			undo_redo.add_undo_property(svs, 'polygon', polygon_2d)

	if _copy_buffer.has_stroke:
		if _copy_buffer.use_line_2d:
			var line := svs.line if is_instance_valid(svs.line) else Line2D.new()
			if not is_instance_valid(svs.line):
				line.name = "Stroke"
				undo_redo.add_do_property(svs, 'line', line)
				undo_redo.add_do_method(svs, 'add_child', line, true)
				undo_redo.add_do_method(line, 'set_owner', scene_root)
				undo_redo.add_undo_reference(line)
				undo_redo.add_undo_method(svs, 'remove_child', line)
				undo_redo.add_undo_property(svs, 'line', null)
			undo_redo.add_do_property(line, 'width_curve', _copy_buffer.width_curve)
			undo_redo.add_undo_property(line, 'width_curve', line.width_curve)
		else:
			if not is_instance_valid(svs.poly_stroke):
				var poly_stroke := Polygon2D.new()
				poly_stroke.name = "Stroke"
				undo_redo.add_do_property(svs, 'poly_stroke', poly_stroke)
				undo_redo.add_do_method(svs, 'add_child', poly_stroke, true)
				undo_redo.add_do_method(poly_stroke, 'set_owner', scene_root)
				undo_redo.add_undo_reference(poly_stroke)
				undo_redo.add_undo_method(svs, 'remove_child', poly_stroke)
				undo_redo.add_undo_property(svs, 'poly_stroke', null)
	else:
		if is_instance_valid(svs.line):
			var line := svs.line
			undo_redo.add_do_method(svs, 'remove_child', line)
			undo_redo.add_do_property(svs, 'line', null)
			undo_redo.add_undo_method(svs, 'add_child', line, true)
			undo_redo.add_undo_method(line, 'set_owner', EditorInterface.get_edited_scene_root())
			undo_redo.add_undo_reference(line)
			undo_redo.add_undo_property(svs, 'line', line)
		if is_instance_valid(svs.poly_stroke):
			var polygon_2d := svs.poly_stroke
			undo_redo.add_do_method(svs, 'remove_child', polygon_2d)
			undo_redo.add_do_property(svs, 'poly_stroke', null)
			undo_redo.add_undo_method(svs, 'add_child', polygon_2d, true)
			undo_redo.add_undo_method(polygon_2d, 'set_owner', EditorInterface.get_edited_scene_root())
			undo_redo.add_undo_reference(polygon_2d)
			undo_redo.add_undo_property(svs, 'poly_stroke', polygon_2d)

	undo_redo.add_do_property(svs, 'fill_color', _copy_buffer.fill_color)
	undo_redo.add_undo_property(svs, 'fill_color', svs.fill_color)
	undo_redo.add_do_property(svs, 'stroke_color', _copy_buffer.stroke_color)
	undo_redo.add_undo_property(svs, 'stroke_color', svs.stroke_color)
	undo_redo.add_do_property(svs, 'stroke_width', _copy_buffer.stroke_width)
	undo_redo.add_undo_property(svs, 'stroke_width', svs.stroke_width)
	undo_redo.add_do_property(svs, 'begin_cap_mode', _copy_buffer.line_cap_begin)
	undo_redo.add_undo_property(svs, 'begin_cap_mode', svs.begin_cap_mode)
	undo_redo.add_do_property(svs, 'end_cap_mode', _copy_buffer.line_cap_end)
	undo_redo.add_undo_property(svs, 'end_cap_mode', svs.end_cap_mode)
	undo_redo.add_do_property(svs, 'line_joint_mode', _copy_buffer.line_join)
	undo_redo.add_undo_property(svs, 'line_joint_mode', svs.line_joint_mode)
	undo_redo.add_do_property(svs, 'extrusion_direction', _copy_buffer.stroke_extrusion)
	undo_redo.add_undo_property(svs, 'extrusion_direction', svs.extrusion_direction)
	undo_redo.add_do_method(svs, 'notify_assigned_node_change')
	undo_redo.add_undo_method(svs, 'notify_assigned_node_change')
	if do_commit:
		undo_redo.commit_action()

