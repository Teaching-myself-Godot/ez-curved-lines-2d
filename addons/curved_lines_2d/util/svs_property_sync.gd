@tool
class_name SVSPropertySync extends Object


static func synchronize_svs_with_changed_properties(svs : ScalableVectorShape2D) -> void:
	push_warning("TODO: sync _all_ properties of the selected shape to the updated project settings")
	_sync_fill_color(svs)
	_sync_stroke_color(svs)
	_sync_stroke_width(svs)
	_sync_collision_object(svs)
	_sync_polygon(svs)
	_sync_line_2d(svs)
	_sync_poly_stroke(svs)


static func _sync_fill_color(svs : ScalableVectorShape2D) -> void:
	if svs.fill_color != CurvedLines2D._get_default_fill_color():
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Set fill_color for " + str(svs))
		undo_redo.add_do_property(svs, "fill_color", CurvedLines2D._get_default_fill_color())
		undo_redo.add_undo_property(svs, "fill_color", svs.fill_color)
		undo_redo.commit_action()


static func _sync_stroke_color(svs : ScalableVectorShape2D) -> void:
	if svs.stroke_color != CurvedLines2D._get_default_stroke_color():
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Set stroke_color for " + str(svs))
		undo_redo.add_do_property(svs, "stroke_color", CurvedLines2D._get_default_stroke_color())
		undo_redo.add_undo_property(svs, "stroke_color", svs.stroke_color)
		undo_redo.commit_action()


static func _sync_stroke_width(svs : ScalableVectorShape2D) -> void:
	if svs.stroke_width != CurvedLines2D._get_default_stroke_width():
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Set stroke_width for " + str(svs))
		undo_redo.add_do_property(svs, "stroke_width", CurvedLines2D._get_default_stroke_width())
		undo_redo.add_undo_property(svs, "stroke_width", svs.stroke_width)
		undo_redo.commit_action()


static func _sync_collision_object(svs : ScalableVectorShape2D) -> void:
	if svs.get_collision_object_type() != CurvedLines2D._add_collision_object_type():
		var new_obj := _get_collision_object(CurvedLines2D._add_collision_object_type())
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Set collision_object for " + str(svs))
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


static func _sync_polygon(svs : ScalableVectorShape2D) -> void:
	if is_instance_valid(svs.polygon) and not CurvedLines2D._is_add_fill_enabled():
		var polygon_2d := svs.polygon
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Remove Polygon2D from %s " % str(svs))
		undo_redo.add_do_method(svs, 'remove_child', polygon_2d)
		undo_redo.add_do_property(svs, 'polygon', null)
		undo_redo.add_undo_method(svs, 'add_child', polygon_2d, true)
		undo_redo.add_undo_method(polygon_2d, 'set_owner', EditorInterface.get_edited_scene_root())
		undo_redo.add_undo_reference(polygon_2d)
		undo_redo.add_undo_property(svs, 'polygon', polygon_2d)
		undo_redo.commit_action()
	elif not is_instance_valid(svs.polygon) and CurvedLines2D._is_add_fill_enabled():
		var polygon_2d := Polygon2D.new()
		polygon_2d.color = CurvedLines2D._get_default_fill_color()
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Add Polygon2D to %s " % str(svs))
		undo_redo.add_do_method(svs, 'add_child', polygon_2d, true)
		undo_redo.add_do_method(polygon_2d, 'set_owner', EditorInterface.get_edited_scene_root())
		undo_redo.add_do_reference(polygon_2d)
		undo_redo.add_do_property(svs, 'polygon', polygon_2d)
		undo_redo.add_undo_method(svs, 'remove_child', polygon_2d)
		undo_redo.add_undo_property(svs, 'polygon', null)
		undo_redo.commit_action()


static func _sync_line_2d(svs : ScalableVectorShape2D) -> void:
	if CurvedLines2D._is_add_stroke_enabled() and CurvedLines2D._using_line_2d_for_stroke() and not is_instance_valid(svs.line):
		print(CurvedLines2D._using_line_2d_for_stroke())
		push_warning("TODO: Add line via bottom dock")
	elif (
		(is_instance_valid(svs.line) and not CurvedLines2D._is_add_stroke_enabled())
			or
		(is_instance_valid(svs.line) and not CurvedLines2D._using_line_2d_for_stroke())
	):
		push_warning("TODO: remove line via bottom dock")


static func _sync_poly_stroke(svs : ScalableVectorShape2D) -> void:
	if (CurvedLines2D._is_add_stroke_enabled() and not CurvedLines2D._using_line_2d_for_stroke()) and not is_instance_valid(svs.poly_stroke):
		push_warning("TODO: Add poly_stroke via bottom dock")
	elif (
		(is_instance_valid(svs.poly_stroke) and not CurvedLines2D._is_add_stroke_enabled())
			or
		(is_instance_valid(svs.poly_stroke) and CurvedLines2D._using_line_2d_for_stroke())
	):
		push_warning("TODO: remove poly_stroke via bottom dock")


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
