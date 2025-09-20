@tool
extends EditorInspectorPlugin

class_name  Line2DGeneratorInspectorPlugin

const GROUP_NAME_CURVE_SETTINGS := "Curve settings"
const GROUP_NAME_EXPORT_OPTIONS := "Export Options"

var LineCapEditor = preload("res://addons/curved_lines_2d/line_cap_editor_property.gd")
var LineJointModeEditor = preload("res://addons/curved_lines_2d/line_joint_editor_property.gd")

func _can_handle(obj) -> bool:
	return (
		obj is DrawablePath2D or
		obj is ScalableVectorShape2D or
		obj is AdaptableVectorShape3D or
		obj is TextureRect or
		obj is Button or
		obj is TextureButton
	)


func _parse_begin(object: Object) -> void:
	if object is DrawablePath2D:
		var warning_label := Label.new()
		warning_label.text = "⚠️ DrawablePath2D is Deprecated"
		add_custom_control(warning_label)
		var button : Button = Button.new()
		button.text = "Convert to ScalableVectorShape2D"
		add_custom_control(button)
		button.pressed.connect(func(): _on_convert_button_pressed(object))
	if object is ScalableVectorShape2D and object.shape_type != ScalableVectorShape2D.ShapeType.PATH:
		var button : Button = Button.new()
		button.text = "Convert to Path*"
		button.tooltip_text = "Pressing this button will change the way it is edited to Path mode."
		add_custom_control(button)
		button.pressed.connect(func(): _on_convert_to_path_button_pressed(object, button))


func _parse_group(object: Object, group: String) -> void:
	if group == GROUP_NAME_CURVE_SETTINGS and object is ScalableVectorShape2D:
		var key_frame_form = load("res://addons/curved_lines_2d/batch_insert_curve_point_key_frames_inspector_form.tscn").instantiate()
		key_frame_form.scalable_vector_shape_2d = object
		add_custom_control(key_frame_form)
	elif group == GROUP_NAME_EXPORT_OPTIONS and object is ScalableVectorShape2D:
		var box := VBoxContainer.new()
		var export_png_button : Button = Button.new()
		export_png_button.text = "Export as PNG*"
		export_png_button.tooltip_text = "The export will only contain this node and its children,
				assigned nodes outside this subtree will not be drawn."
		var bake_button : Button = Button.new()
		bake_button.text = "Export as baked scene*"
		bake_button.tooltip_text = "The export will only contain this node and its children,
				assigned nodes outside this subtree will not be drawn.\n
				⚠️ Warning: An exported AnimationPlayer will not support animated curves"
		var export_3d_scene_button := Button.new()
		export_3d_scene_button.text = "Export 3D scene*"
		export_3d_scene_button.tooltip_text = "This export uses CSGPolygon3D\n
				⚠️ Warning: AnimationPlayer will be ignored for export, to animate curves, use the 'path_changed' or 'polygons_updated' signal (advanced)"
		box.add_theme_constant_override("separation", 5)
		box.add_spacer(true)
		box.add_child(export_png_button)
		box.add_child(bake_button)
		box.add_child(export_3d_scene_button)
		box.add_spacer(false)
		add_custom_control(box)
		export_png_button.pressed.connect(func(): _on_export_png_button_pressed(object))
		bake_button.pressed.connect(func(): _show_exported_scene_dialog(object, _export_baked_scene))
		export_3d_scene_button.pressed.connect(func(): _show_exported_scene_dialog(object, _export_3d_scene))


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if name == "line" and (object is  ScalableVectorShape2D):
		var assign_stroke_inspector_form = load("res://addons/curved_lines_2d/assign_stroke_inspector_form.tscn").instantiate()
		assign_stroke_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_stroke_inspector_form)
	elif name == "polygon" and (object  is ScalableVectorShape2D):
		var assign_fill_inspector_form = load("res://addons/curved_lines_2d/assign_fill_inspector_form.tscn").instantiate()
		assign_fill_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_fill_inspector_form)
	elif name == "collision_polygon" and (object is ScalableVectorShape2D):
		#if object.collision_polygon == null:
			#return true
		var assign_collision_inspector_form = load("res://addons/curved_lines_2d/assign_collision_inspector_form.tscn").instantiate()
		assign_collision_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_collision_inspector_form)
	elif name == "collision_object" and (object is ScalableVectorShape2D):
		var assign_collision_inspector_form = load("res://addons/curved_lines_2d/assign_collision_object_inspector_form.tscn").instantiate()
		assign_collision_inspector_form.scalable_vector_shape_2d = object
		add_custom_control(assign_collision_inspector_form)
	elif name == "navigation_region" and (object is ScalableVectorShape2D):
		var assign_nav_form = load("res://addons/curved_lines_2d/assign_navigation_region_inspector_form.tscn").instantiate()
		assign_nav_form.scalable_vector_shape_2d = object as ScalableVectorShape2D
		add_custom_control(assign_nav_form)
	elif name == "show_export_options" and (object is ScalableVectorShape2D):
		return true
	elif (name == "begin_cap_mode" or name == "end_cap_mode") and (object is ScalableVectorShape2D):
		add_property_editor(name, LineCapEditor.new())
		return true
	elif name == "line_joint_mode" and (object is ScalableVectorShape2D):
		add_property_editor(name, LineJointModeEditor.new())
		return true
	elif name == "guide_svs" and object is AdaptableVectorShape3D:
		if object.has_meta(AdaptableVectorShape3D.STORED_CURVE_META_NAME) and object.guide_svs == null:
			var button := Button.new()
			button.text = "Add 2D Shape Editor"
			add_custom_control(button)
			button.pressed.connect(func(): _add_guide_svs(object))
			return true
	elif object is TextureRect or object is Button or object is TextureButton:
		var svg_texture_helpers : Array[Node] = (
				object.get_children().filter(func(ch): return ch is SVGTextureHelper)
		)
		if name in svg_texture_helpers.map(func(x): return x.target_property):
			var helper = svg_texture_helpers.filter(func(x): return x.target_property == name).pop_back()
			var box = VBoxContainer.new()
			var button := Button.new()
			button.text = name.replace("texture_", "").to_pascal_case()
			button.tooltip_text = '''Select a new SVG file as a texture. Remove the SVGTextureHelper
					child node of this node to set a texture the godot way again.'''
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.icon = object.get(name)
			button.expand_icon = true
			button.custom_minimum_size.y = 48
			box.add_spacer(true)
			box.add_child(button)
			button.pressed.connect(func(): _on_change_svg_helper_pressed(object, helper, name))
			add_custom_control(box)
			return true
		elif hint_string == "Texture2D":
			var box = VBoxContainer.new()
			var button := Button.new()
			button.text = "Set Scalable SVG Texture*"
			button.tooltip_text = '''Pressing this button will create
					an SVGTextureHelper child node, which then manages an auto-
					scaling texture based on an SVG file.'''
			box.add_spacer(true)
			box.add_child(button)
			button.pressed.connect(func(): _on_add_svg_helper_pressed(object, name, button))
			add_custom_control(box)
			return false
		if svg_texture_helpers.size() > 0 and (
			name == "expand_mode" or #name == "stretch_mode" or
			name == "expand_icon" or name == "ignore_texture_size"
		):
			return true
	return false


func _on_convert_button_pressed(orig : DrawablePath2D):
	var replacement := ScalableVectorShape2D.new()
	replacement.transform = orig.transform
	replacement.tolerance_degrees = orig.tolerance_degrees
	replacement.max_stages = orig.max_stages
	replacement.lock_assigned_shapes = orig.lock_assigned_shapes
	replacement.update_curve_at_runtime = orig.update_curve_at_runtime
	if orig.curve:
		replacement.curve = orig.curve
	if is_instance_valid(orig.line):
		replacement.line = orig.line
	if is_instance_valid(orig.polygon):
		replacement.polygon = orig.polygon
	if is_instance_valid(orig.collision_polygon):
		replacement.collision_polygon = orig.collision_polygon
	orig.replace_by(replacement, true)
	replacement.name = "ScalableVectorShape2D" if orig.name == "DrawablePath2D" else orig.name
	EditorInterface.call_deferred('edit_node', replacement)


func _on_convert_to_path_button_pressed(svs : ScalableVectorShape2D, button : Button):
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Change shape type to path for %s" % str(svs))
	undo_redo.add_do_property(svs, 'shape_type', ScalableVectorShape2D.ShapeType.PATH)
	undo_redo.add_undo_property(svs, 'shape_type', svs.shape_type)
	undo_redo.add_undo_property(svs, 'size', svs.size)
	undo_redo.add_undo_property(svs, 'rx', svs.rx)
	undo_redo.add_undo_property(svs, 'ry', svs.ry)
	undo_redo.add_undo_property(svs, 'offset', svs.offset)
	undo_redo.commit_action()
	button.hide()


func _on_change_svg_helper_pressed(parent_control : Control, helper : SVGTextureHelper, target_property : String):
	var dialog := EditorFileDialog.new()
	dialog.add_filter("*.svg", "SVG Image")
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.file_selected.connect(func(path):
			dialog.queue_free()
			helper.svg_resource.svg_file_path = path
			parent_control.notify_property_list_changed()
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 400))



func _on_add_svg_helper_pressed(parent_control : Control, target_property : String, button : Button):
	var dialog := EditorFileDialog.new()
	dialog.add_filter("*.svg", "SVG Image")
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.file_selected.connect(func(path):
			dialog.queue_free()
			_add_svg_helper(path, parent_control, target_property, button))
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 400))


func _add_svg_helper(file_path : String, parent_control : Control, target_property : String, button : Button):
	var svg_helper := SVGTextureHelper.new()
	svg_helper.name = "%sSVGTextureHelper" % target_property.to_pascal_case()
	parent_control.add_child(svg_helper, true)
	svg_helper.owner = parent_control.owner
	svg_helper.target_property = target_property
	svg_helper.svg_resource = SVGResource.new()
	svg_helper.svg_resource.svg_file_path = file_path
	parent_control.notify_property_list_changed()
	button.hide()


static func _on_export_png_button_pressed(export_root_node : Node) -> void:
	var dialog := EditorFileDialog.new()
	dialog.add_filter("*.png", "PNG image")
	dialog.current_file = export_root_node.name.to_snake_case()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.file_selected.connect(func(path): _export_png(export_root_node, path, dialog))
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 400))


static func _show_exported_scene_dialog(export_root_node : Node, callable : Callable) -> void:
	var dialog := EditorFileDialog.new()
	dialog.add_filter("*.tscn", "Scene")
	dialog.current_file = export_root_node.name.to_snake_case()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.file_selected.connect(func(path): callable.call(export_root_node, path, dialog))
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 400))


static func _export_image(export_root_node : Node, stored_box : Dictionary[String, Vector2] = {}) -> Image:
	var sub_viewport := SubViewport.new()
	EditorInterface.get_base_control().add_child(sub_viewport)
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


static func _export_png(export_root_node : Node, filename : String, dialog : Node) -> void:
	dialog.queue_free()
	var img = await _export_image(export_root_node)
	img.save_png(filename)
	EditorInterface.get_resource_filesystem().scan()


static func _export_3d_scene(export_root_node : Node, filepath : String, dialog : Node) -> void:
	dialog.queue_free()
	var new_node := Node3D.new()
	new_node.name = "%s3D" % export_root_node.name
	EditorInterface.get_edited_scene_root().add_child(new_node, true)
	new_node.owner = EditorInterface.get_edited_scene_root()
	var result := _copy_as_3d_node(export_root_node, new_node, EditorInterface.get_edited_scene_root())
	if result is Node3D:
		result.rotation_degrees.x = 180.0
	for node in new_node.get_children():
		_recursive_set_owner(node, new_node, EditorInterface.get_edited_scene_root())
	var scene := PackedScene.new()
	scene.pack(new_node)
	ResourceSaver.save(scene, filepath, ResourceSaver.FLAG_NONE)
	new_node.queue_free()
	EditorInterface.open_scene_from_path(filepath)


func _add_guide_svs(avs_3d : AdaptableVectorShape3D) -> void:
	var guide_svs := ScalableVectorShape2D.new()
	guide_svs.name = "ShapeEditorScalableVectorShape2D"
	guide_svs.update_curve_at_runtime = true
	guide_svs.curve = avs_3d.get_meta(AdaptableVectorShape3D.STORED_CURVE_META_NAME)
	guide_svs.arc_list = avs_3d.get_meta(AdaptableVectorShape3D.STORED_ARC_LIST_META_NAME)
	guide_svs.shape_type = avs_3d.get_meta(AdaptableVectorShape3D.STORED_SHAPE_TYPE_META_NAME)
	guide_svs.size = avs_3d.get_meta(AdaptableVectorShape3D.STORED_SIZE_META_NAME)
	guide_svs.offset = avs_3d.get_meta(AdaptableVectorShape3D.STORED_OFFSET_META_NAME)
	guide_svs.stroke_width = avs_3d.get_meta(AdaptableVectorShape3D.STORED_STROKE_WIDTH_META_NAME)
	guide_svs.begin_cap_mode =  avs_3d.get_meta(AdaptableVectorShape3D.STORED_LINE_CAP_META_NAME)
	guide_svs.line_joint_mode = avs_3d.get_meta(AdaptableVectorShape3D.STORED_JOINT_MODE_META_NAME)
	guide_svs.rx = avs_3d.get_meta(AdaptableVectorShape3D.STORED_RX_META_NAME)
	guide_svs.ry = avs_3d.get_meta(AdaptableVectorShape3D.STORED_RY_META_NAME)
	avs_3d.add_child(guide_svs, true)
	guide_svs.owner = avs_3d.owner

	if not avs_3d.fill_polygons.is_empty():
		guide_svs.polygon = Polygon2D.new()
		guide_svs.polygon.name = avs_3d.fill_polygons[0].name
		guide_svs.add_child(guide_svs.polygon, true)
		guide_svs.polygon.owner = avs_3d.owner
		guide_svs.polygon.color = avs_3d.fill_polygons[0].material.albedo_color
		guide_svs.polygon.texture = avs_3d.fill_polygons[0].material.albedo_texture
	if not avs_3d.stroke_polygons.is_empty():
		guide_svs.poly_stroke = Polygon2D.new()
		guide_svs.poly_stroke.name = avs_3d.stroke_polygons[0].name
		guide_svs.add_child(guide_svs.poly_stroke, true)
		guide_svs.poly_stroke.owner = avs_3d.owner
		guide_svs.stroke_color = avs_3d.stroke_polygons[0].material.albedo_color
		guide_svs.poly_stroke.texture = avs_3d.stroke_polygons[0].material.albedo_texture
	avs_3d.guide_svs = guide_svs


static func _copy_as_3d_node(src_node : Node, dst_parent : Node, dst_owner : Node, node_depth := 0, render_depth := 0) -> Node:
	if (src_node is Polygon2D or src_node is Line2D) and src_node.get_child_count() == 0:
		return null
	var dst_node : Node = (
		AdaptableVectorShape3D.new() if src_node is ScalableVectorShape2D else
		Node3D.new() if src_node is Node2D else Node.new()
	)
	dst_node.name = src_node.name
	dst_parent.add_child(dst_node, true)
	if dst_node is Node3D:
		dst_node.transform = src_node.transform
		dst_node.position.z = -(node_depth + render_depth) * 0.02
	if src_node is ScalableVectorShape2D and src_node.is_visible_in_tree():
		dst_node.set_meta(AdaptableVectorShape3D.STORED_CURVE_META_NAME, src_node.curve.duplicate())
		dst_node.set_meta(AdaptableVectorShape3D.STORED_ARC_LIST_META_NAME, src_node.arc_list.duplicate(true))
		dst_node.set_meta(AdaptableVectorShape3D.STORED_SHAPE_TYPE_META_NAME, src_node.shape_type)
		dst_node.set_meta(AdaptableVectorShape3D.STORED_SIZE_META_NAME, src_node.size)
		dst_node.set_meta(AdaptableVectorShape3D.STORED_OFFSET_META_NAME, src_node.offset)
		dst_node.set_meta(AdaptableVectorShape3D.STORED_STROKE_WIDTH_META_NAME, src_node.stroke_width)
		dst_node.set_meta(AdaptableVectorShape3D.STORED_RX_META_NAME, src_node.rx)
		dst_node.set_meta(AdaptableVectorShape3D.STORED_RY_META_NAME, src_node.ry)
		dst_node.set_meta(AdaptableVectorShape3D.STORED_LINE_CAP_META_NAME, src_node.begin_cap_mode)
		dst_node.set_meta(AdaptableVectorShape3D.STORED_JOINT_MODE_META_NAME, src_node.line_joint_mode)

		var has_valid_stroke : bool = (
				is_instance_valid(src_node.line) or is_instance_valid(src_node.poly_stroke)
		) and src_node.stroke_width > 0.0
		if is_instance_valid(src_node.polygon):
			var target_z_index := 1
			if has_valid_stroke and not AdaptableVectorShape3D.is_stroke_in_front_of_fill(src_node):
				target_z_index = 0
			for csg_polygon in AdaptableVectorShape3D.extract_csg_polygons_from_scalable_vector_shapes(
						src_node, false, false, target_z_index):
				dst_node.add_child(csg_polygon, true)
				dst_node.fill_polygons.append(csg_polygon)
				csg_polygon.owner = dst_owner
		if has_valid_stroke:
			for csg_polygon in AdaptableVectorShape3D.extract_csg_polygons_from_scalable_vector_shapes(
						src_node, true, is_instance_valid(src_node.line),
						(0 if AdaptableVectorShape3D.is_stroke_in_front_of_fill(src_node) else 1)
			):
				dst_node.add_child(csg_polygon, true)
				dst_node.stroke_polygons.append(csg_polygon)
				csg_polygon.owner = dst_owner

	dst_node.owner = dst_owner
	render_depth = node_depth
	for ch in src_node.get_children().filter(func(ch): return ch != dst_parent):
		render_depth += 1
		var result := _copy_as_3d_node(ch, dst_node, dst_owner, node_depth + 1, render_depth)
	return dst_node


static func _export_baked_scene(export_root_node : Node, filepath : String, dialog : Node) -> void:
	dialog.queue_free()
	var new_node := Node2D.new()
	EditorInterface.get_edited_scene_root().add_child(new_node)
	new_node.owner = EditorInterface.get_edited_scene_root()
	var result := _copy_baked_node(export_root_node, new_node, EditorInterface.get_edited_scene_root())
	result.transform = Transform2D.IDENTITY
	for node in result.get_children():
		_recursive_set_owner(node, result, EditorInterface.get_edited_scene_root())
	var scene := PackedScene.new()
	scene.pack(result)
	ResourceSaver.save(scene, filepath, ResourceSaver.FLAG_NONE)
	new_node.queue_free()
	EditorInterface.open_scene_from_path(filepath)


static func _copy_baked_node(src_node : Node, dst_parent : Node, dst_owner : Node) -> Node:
	if src_node is ScalableVectorShape2D and src_node.get_children().is_empty():
		return null
	var dst_node : Node = (
		Node2D.new() if src_node is ScalableVectorShape2D else
		ClassDB.instantiate(src_node.get_class())
	)
	dst_parent.add_child(dst_node)

	for prop in src_node.get_property_list():
		if prop.name == "owner":
			continue
		if src_node is ScalableVectorShape2D and prop.name == "script":
			break
		if prop.name in dst_node:
			dst_node.set(prop.name, src_node.get(prop.name))

	dst_node.owner = dst_owner
	for ch in src_node.get_children().filter(func(ch): return ch != dst_parent):
		_copy_baked_node(ch, dst_node, dst_owner)
	return dst_node


static func _recursive_set_owner(node : Node, new_owner : Node, root : Node):
	if node.owner != root:
		return
	node.set_owner(new_owner)
	for child in node.get_children():
		_recursive_set_owner(child, new_owner, root)
