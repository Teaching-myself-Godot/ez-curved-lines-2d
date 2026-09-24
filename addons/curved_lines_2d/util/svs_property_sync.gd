@tool
class_name SVSPropertySync extends Object

const PREVIOUS_COLOR_META_NAME := "_previous_color_"

static func _get_svs_selection() -> Array[Node]:
	return (
		EditorInterface.get_selection().get_selected_nodes()
			.filter(func(n): return is_instance_valid(n))
			.filter(func(n): return n is ScalableVectorShape2D)
	)


static func sync_fill_color(commit : bool, remember_color := false) -> void:
	if commit:
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Set fill_color")
		for svs : ScalableVectorShape2D in _get_svs_selection():
			var previous := svs.get_meta(PREVIOUS_COLOR_META_NAME) if svs.has_meta(PREVIOUS_COLOR_META_NAME) else svs.fill_color
			undo_redo.add_do_property(svs, "fill_color", CurvedLines2D._get_default_fill_color())
			undo_redo.add_undo_property(svs, "fill_color", previous)
			if svs.has_meta(PREVIOUS_COLOR_META_NAME):
				svs.remove_meta(PREVIOUS_COLOR_META_NAME)
		undo_redo.commit_action()
	else:
		for svs : ScalableVectorShape2D in _get_svs_selection():
			if remember_color:
				svs.set_meta(PREVIOUS_COLOR_META_NAME, svs.fill_color)
			svs.fill_color = CurvedLines2D._get_default_fill_color()


static func sync_stroke_color(commit : bool, remember_color := false) -> void:
	if commit:
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Set stroke_color")
		for svs : ScalableVectorShape2D in _get_svs_selection():
			var previous := svs.get_meta(PREVIOUS_COLOR_META_NAME) if svs.has_meta(PREVIOUS_COLOR_META_NAME) else svs.stroke_color
			undo_redo.add_do_property(svs, "stroke_color", CurvedLines2D._get_default_stroke_color())
			undo_redo.add_undo_property(svs, "stroke_color", previous)
			if svs.has_meta(PREVIOUS_COLOR_META_NAME):
				svs.remove_meta(PREVIOUS_COLOR_META_NAME)
		undo_redo.commit_action()
	else:
		for svs : ScalableVectorShape2D in _get_svs_selection():
			if remember_color:
				svs.set_meta(PREVIOUS_COLOR_META_NAME, svs.stroke_color)
			svs.stroke_color = CurvedLines2D._get_default_stroke_color()


static func sync_stroke_width() -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set stroke_width")
	for svs : ScalableVectorShape2D in _get_svs_selection():
		undo_redo.add_do_property(svs, "stroke_width", CurvedLines2D._get_default_stroke_width())
		undo_redo.add_undo_property(svs, "stroke_width", svs.stroke_width)
	undo_redo.commit_action()


static func sync_begin_cap() -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set begin_cap_mode")
	for svs : ScalableVectorShape2D in _get_svs_selection():
		undo_redo.add_do_property(svs, "begin_cap_mode", CurvedLines2D._get_default_begin_cap())
		undo_redo.add_undo_property(svs, "begin_cap_mode", svs.begin_cap_mode)
	undo_redo.commit_action()


static func sync_collision_object() -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set collision_object")
	for svs : ScalableVectorShape2D in _get_svs_selection():
		if svs.get_collision_object_type() != CurvedLines2D._add_collision_object_type():
			var new_obj := _get_collision_object(CurvedLines2D._add_collision_object_type())
			if is_instance_valid(svs.collision_object) and svs.collision_object.get_parent():
				undo_redo.add_do_method(svs.collision_object.get_parent(), 'remove_child', svs.collision_object)
				undo_redo.add_undo_method(svs.collision_object.get_parent(), 'add_child', svs.collision_object)
				undo_redo.add_do_reference(svs.collision_object)
				undo_redo.add_undo_method(svs.collision_object, 'set_owner', svs.owner)
			if new_obj:
				undo_redo.add_do_method(svs, 'add_child', new_obj, true)
				if svs == EditorInterface.get_edited_scene_root():
					undo_redo.add_do_method(new_obj, 'set_owner', svs)
				else:
					undo_redo.add_do_method(new_obj, 'set_owner', svs.owner)
				undo_redo.add_undo_reference(new_obj)
				undo_redo.add_undo_method(svs, 'remove_child', new_obj)
			undo_redo.add_do_property(svs, 'collision_object', new_obj)
			undo_redo.add_undo_property(svs, 'collision_object', svs.collision_object)
	undo_redo.commit_action()


static func sync_polygon() -> void:
	if CurvedLines2D._is_add_fill_enabled():
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Add Fill")
		for svs : ScalableVectorShape2D in _get_svs_selection():
			if is_instance_valid(svs.polygon):
				continue
			var polygon_2d := Polygon2D.new()
			polygon_2d.color = CurvedLines2D._get_default_fill_color()
			undo_redo.add_do_method(svs, 'add_child', polygon_2d, true)
			undo_redo.add_do_method(polygon_2d, 'set_owner', EditorInterface.get_edited_scene_root())
			undo_redo.add_do_reference(polygon_2d)
			undo_redo.add_do_property(svs, 'polygon', polygon_2d)
			undo_redo.add_undo_method(svs, 'remove_child', polygon_2d)
			undo_redo.add_undo_property(svs, 'polygon', null)
		undo_redo.commit_action()
	else:
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Remove Fill")
		for svs : ScalableVectorShape2D in _get_svs_selection():
			if not is_instance_valid(svs.polygon):
				svs.polygon = null
				continue
			var polygon_2d := svs.polygon
			undo_redo.add_do_method(svs, 'remove_child', polygon_2d)
			undo_redo.add_do_property(svs, 'polygon', null)
			undo_redo.add_undo_method(svs, 'add_child', polygon_2d, true)
			undo_redo.add_undo_method(polygon_2d, 'set_owner', EditorInterface.get_edited_scene_root())
			undo_redo.add_undo_reference(polygon_2d)
			undo_redo.add_undo_property(svs, 'polygon', polygon_2d)
		undo_redo.commit_action()


static func sync_stroke() -> void:
	for svs : ScalableVectorShape2D in _get_svs_selection():
		if CurvedLines2D._is_add_stroke_enabled() and CurvedLines2D._using_line_2d_for_stroke() and not is_instance_valid(svs.line):
			var line_2d := Line2D.new()
			var root := EditorInterface.get_edited_scene_root()
			var undo_redo = EditorInterface.get_editor_undo_redo()
			line_2d.name = "Stroke"
			line_2d.default_color = svs.stroke_color
			line_2d.width = svs.stroke_width
			line_2d.begin_cap_mode = svs.begin_cap_mode
			line_2d.end_cap_mode = svs.end_cap_mode
			line_2d.joint_mode = svs.line_joint_mode
			line_2d.sharp_limit = 90.0
			if CurvedLines2D._use_antialiased_line_2d():
				line_2d.texture = load("res://addons/curved_lines_2d/LumAlpha8.tex")
				line_2d.texture_mode = Line2D.LINE_TEXTURE_TILE
				line_2d.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			undo_redo.create_action("Add Line2D to %s " % str(svs))
			undo_redo.add_do_method(svs, 'add_child', line_2d, true)
			undo_redo.add_do_method(line_2d, 'set_owner', root)
			undo_redo.add_do_reference(line_2d)
			undo_redo.add_do_property(svs, 'line', line_2d)
			undo_redo.add_undo_method(svs, 'remove_child', line_2d)
			undo_redo.add_undo_property(svs, 'line', null)
			undo_redo.commit_action()
		elif (
			(is_instance_valid(svs.line) and not CurvedLines2D._is_add_stroke_enabled())
				or
			(is_instance_valid(svs.line) and not CurvedLines2D._using_line_2d_for_stroke())
		):
			var line_2d := svs.line
			var undo_redo := EditorInterface.get_editor_undo_redo()
			undo_redo.create_action("Remove Line2D from %s " % str(svs))
			undo_redo.add_do_method(svs, 'remove_child', line_2d)
			undo_redo.add_do_property(svs, 'line', null)
			undo_redo.add_undo_method(svs, 'add_child', line_2d, true)
			undo_redo.add_undo_method(line_2d, 'set_owner', EditorInterface.get_edited_scene_root())
			undo_redo.add_undo_reference(line_2d)
			undo_redo.add_undo_property(svs, 'line', line_2d)
			if CurvedLines2D._is_add_stroke_enabled():
				_add_polystroke(svs, undo_redo)
			undo_redo.commit_action()
		if (CurvedLines2D._is_add_stroke_enabled() and not CurvedLines2D._using_line_2d_for_stroke()) and not is_instance_valid(svs.poly_stroke):
			var undo_redo = EditorInterface.get_editor_undo_redo()
			undo_redo.create_action("Add Polygon2D for Stroke to %s " % str(svs))
			_add_polystroke(svs, undo_redo)
			undo_redo.commit_action()
		elif (
			(is_instance_valid(svs.poly_stroke) and not CurvedLines2D._is_add_stroke_enabled())
				or
			(is_instance_valid(svs.poly_stroke) and CurvedLines2D._using_line_2d_for_stroke())
		):
			var poly_stroke := svs.poly_stroke
			var undo_redo := EditorInterface.get_editor_undo_redo()
			undo_redo.create_action("Remove Line2D from %s " % str(svs))
			undo_redo.add_do_method(svs, 'remove_child', poly_stroke)
			undo_redo.add_do_property(svs, 'poly_stroke', null)
			undo_redo.add_undo_method(svs, 'add_child', poly_stroke, true)
			undo_redo.add_undo_method(poly_stroke, 'set_owner', EditorInterface.get_edited_scene_root())
			undo_redo.add_undo_reference(poly_stroke)
			undo_redo.add_undo_property(svs, 'poly_stroke', poly_stroke)
			undo_redo.commit_action()


static func _add_polystroke(svs : ScalableVectorShape2D, undo_redo : EditorUndoRedoManager) -> void:
	var root := EditorInterface.get_edited_scene_root()
	var poly_stroke := Polygon2D.new()
	poly_stroke.name = "PolyStroke"
	poly_stroke.color = svs.stroke_color
	undo_redo.add_do_method(svs, 'add_child', poly_stroke, true)
	undo_redo.add_do_method(poly_stroke, 'set_owner', root)
	undo_redo.add_do_reference(poly_stroke)
	undo_redo.add_do_property(svs, 'poly_stroke', poly_stroke)
	undo_redo.add_undo_method(svs, 'remove_child', poly_stroke)
	undo_redo.add_undo_property(svs, 'poly_stroke', null)


static func _get_collision_object(obj_type : ScalableVectorShape2D.CollisionObjectType) -> CollisionObject2D:
	match obj_type:
		ScalableVectorShape2D.CollisionObjectType.STATIC_BODY_2D:
			return StaticBody2D.new()
		ScalableVectorShape2D.CollisionObjectType.AREA_2D:
			return Area2D.new()
		ScalableVectorShape2D.CollisionObjectType.ANIMATABLE_BODY_2D:
			return AnimatableBody2D.new()
		ScalableVectorShape2D.CollisionObjectType.RIGID_BODY_2D:
			return RigidBody2D.new()
		ScalableVectorShape2D.CollisionObjectType.CHARACTER_BODY_2D:
			return CharacterBody2D.new()
		ScalableVectorShape2D.CollisionObjectType.PHYSICAL_BONE_2D:
			return PhysicalBone2D.new()
		_, ScalableVectorShape2D.CollisionObjectType.NONE:
			return null
