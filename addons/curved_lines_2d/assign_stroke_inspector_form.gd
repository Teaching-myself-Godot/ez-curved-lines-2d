@tool
extends Control

var scalable_vector_shape_2d : ScalableVectorShape2D


func _enter_tree() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if 'assigned_node_changed' in scalable_vector_shape_2d:
		scalable_vector_shape_2d.assigned_node_changed.connect(_on_svs_assignment_changed)
	_on_svs_assignment_changed()


func _on_svs_assignment_changed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.line):
		%CreateStrokeButton.get_parent().hide()
		%GotoLine2DButton.get_parent().show()
		%CreateStrokeButton.disabled = true
		%GotoLine2DButton.disabled = false
	else:
		%CreateStrokeButton.get_parent().show()
		%GotoLine2DButton.get_parent().hide()
		%CreateStrokeButton.disabled = false
		%GotoLine2DButton.disabled = true

	if is_instance_valid(scalable_vector_shape_2d.poly_stroke):
		%CreatePolyStrokeButton.get_parent().hide()
		%GotoPolygon2DButton.get_parent().show()
		%CreatePolyStrokeButton.disabled = true
		%GotoPolygon2DButton.disabled = false
	else:
		%CreatePolyStrokeButton.get_parent().show()
		%GotoPolygon2DButton.get_parent().hide()
		%CreatePolyStrokeButton.disabled = false
		%GotoPolygon2DButton.disabled = true


func _on_goto_line_2d_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.line):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.line)


func _on_goto_polygon_2d_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.poly_stroke):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.poly_stroke)


func _on_create_stroke_button_pressed():
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if is_instance_valid(scalable_vector_shape_2d.line):
		return

	var line_2d := Line2D.new()
	var root := EditorInterface.get_edited_scene_root()
	var undo_redo = EditorInterface.get_editor_undo_redo()
	line_2d.name = "Stroke"
	line_2d.default_color = scalable_vector_shape_2d.stroke_color
	line_2d.width = scalable_vector_shape_2d.stroke_width
	line_2d.begin_cap_mode = scalable_vector_shape_2d.begin_cap_mode
	line_2d.end_cap_mode = scalable_vector_shape_2d.end_cap_mode
	line_2d.joint_mode = scalable_vector_shape_2d.line_joint_mode
	line_2d.sharp_limit = 90.0
	if CurvedLines2D._use_antialiased_line_2d():
		line_2d.texture = load("res://addons/curved_lines_2d/LumAlpha8.tex")
		line_2d.texture_mode = Line2D.LINE_TEXTURE_TILE
		line_2d.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	undo_redo.create_action("Add Line2D to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', line_2d, true)
	undo_redo.add_do_method(line_2d, 'set_owner', root)
	undo_redo.add_do_reference(line_2d)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'line', line_2d)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', line_2d)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'line', null)
	undo_redo.commit_action()



func _on_create_poly_stroke_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if is_instance_valid(scalable_vector_shape_2d.poly_stroke):
		return

	var poly_stroke := Polygon2D.new()
	var root := EditorInterface.get_edited_scene_root()
	var undo_redo = EditorInterface.get_editor_undo_redo()
	poly_stroke.name = "PolyStroke"
	poly_stroke.color = scalable_vector_shape_2d.stroke_color

	undo_redo.create_action("Add Polygon2D for Stroke to %s " % str(scalable_vector_shape_2d))
	undo_redo.add_do_method(scalable_vector_shape_2d, 'add_child', poly_stroke, true)
	undo_redo.add_do_method(poly_stroke, 'set_owner', root)
	undo_redo.add_do_reference(poly_stroke)
	undo_redo.add_do_property(scalable_vector_shape_2d, 'poly_stroke', poly_stroke)
	undo_redo.add_undo_method(scalable_vector_shape_2d, 'remove_child', poly_stroke)
	undo_redo.add_undo_property(scalable_vector_shape_2d, 'poly_stroke', null)
	undo_redo.commit_action()
