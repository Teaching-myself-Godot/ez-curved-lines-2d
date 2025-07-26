@tool
extends EditorPlugin

class_name CurvedLines2D

const SETTING_NAME_EDITING_ENABLED := "addons/curved_lines_2d/editing_enabled"
const SETTING_NAME_HINTS_ENABLED := "addons/curved_lines_2d/hints_enabled"
const SETTING_NAME_SHOW_POINT_NUMBERS := "addons/curved_lines_2d/show_point_numbers"
const SETTING_NAME_STROKE_WIDTH := "addons/curved_lines_2d/stroke_width"
const SETTING_NAME_STROKE_COLOR := "addons/curved_lines_2d/stroke_color"
const SETTING_NAME_FILL_COLOR := "addons/curved_lines_2d/fill_color"
const SETTING_NAME_ADD_STROKE_ENABLED := "addons/curved_lines_2d/add_stroke_enabled"
const SETTING_NAME_ADD_FILL_ENABLED := "addons/curved_lines_2d/add_fill_enabled"
const SETTING_NAME_ADD_COLLISION_TYPE = "addons/curved_lines_2d/add_collision_type"

const SETTING_NAME_PAINT_ORDER := "addons/curved_lines_2d/paint_order"
const SETTING_NAME_DEFAULT_LINE_BEGIN_CAP := "addons/curved_lines_2d/line_begin_cap"
const SETTING_NAME_DEFAULT_LINE_END_CAP := "addons/curved_lines_2d/line_end_cap"
const SETTING_NAME_DEFAULT_LINE_JOINT_MODE := "addons/curved_lines_2d/line_joint_mode"
const SETTING_NAME_SNAP_TO_PIXEL := "addons/curved_lines_2d/snap_to_pixel"
const SETTING_NAME_SNAP_RESOLUTION := "addons/curved_lines_2d/snap_resolution"

const META_NAME_HOVER_POINT_IDX := "_hover_point_idx_"
const META_NAME_HOVER_CP_IN_IDX := "_hover_cp_in_idx_"
const META_NAME_HOVER_CP_OUT_IDX := "_hover_cp_out_idx_"
const META_NAME_HOVER_CLOSEST_POINT := "_hover_closest_point_on_curve_"
const META_NAME_HOVER_GRADIENT_FROM := "_hover_gradient_from_"
const META_NAME_HOVER_GRADIENT_TO := "_hover_gradient_to_"
const META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX := "_hover_gradient_color_stop_idx_"
const META_NAME_HOVER_CLOSEST_POINT_ON_GRADIENT_LINE := "_hover_closest_point_on_gradient_"

const META_NAME_SELECT_HINT := "_select_hint_"

const VIEWPORT_ORANGE := Color(0.737, 0.463, 0.337)

enum PaintOrder {
	FILL_STROKE_MARKERS,
	STROKE_FILL_MARKERS,
	FILL_MARKERS_STROKE,
	MARKERS_FILL_STROKE,
	STROKE_MARKERS_FILL,
	MARKERS_STROKE_FILL
}
enum UndoRedoEntry { UNDOS, DOS, NAME, DO_PROPS, UNDO_PROPS }

const PAINT_ORDER_MAP := {
	PaintOrder.FILL_STROKE_MARKERS: ['_add_fill_to_created_shape', '_add_stroke_to_created_shape', '_add_collision_to_created_shape'],
	PaintOrder.STROKE_FILL_MARKERS: ['_add_stroke_to_created_shape', '_add_fill_to_created_shape', '_add_collision_to_created_shape'],
	PaintOrder.FILL_MARKERS_STROKE: ['_add_fill_to_created_shape', '_add_collision_to_created_shape', '_add_stroke_to_created_shape'],
	PaintOrder.MARKERS_FILL_STROKE: ['_add_collision_to_created_shape', '_add_fill_to_created_shape', '_add_stroke_to_created_shape'],
	PaintOrder.STROKE_MARKERS_FILL: ['_add_stroke_to_created_shape', '_add_collision_to_created_shape', '_add_fill_to_created_shape'],
	PaintOrder.MARKERS_STROKE_FILL: ['_add_collision_to_created_shape', '_add_stroke_to_created_shape', '_add_fill_to_created_shape']
}
var plugin : Line2DGeneratorInspectorPlugin
var scalable_vector_shapes_2d_dock
var select_mode_button : Button
var undo_redo : EditorUndoRedoManager
var in_undo_redo_transaction := false
var shape_preview : Curve2D = null
var selection_candidate : Node = null

var undo_redo_transaction : Dictionary = {
	UndoRedoEntry.NAME: "",
	UndoRedoEntry.DOS: [],
	UndoRedoEntry.UNDOS: [],
	UndoRedoEntry.DO_PROPS: [],
	UndoRedoEntry.UNDO_PROPS: []
}

var set_global_position_popup_panel : PopupPanel
var arc_settings_popup_panel : PopupPanel

func _enter_tree():
	scalable_vector_shapes_2d_dock = preload("res://addons/curved_lines_2d/scalable_vector_shapes_2d_dock.tscn").instantiate()
	plugin = preload("res://addons/curved_lines_2d/line_2d_generator_inspector_plugin.gd").new()
	add_inspector_plugin(plugin)
	add_custom_type(
		"DrawablePath2D",
		"Path2D",
		preload("res://addons/curved_lines_2d/drawable_path_2d.gd"),
		preload("res://addons/curved_lines_2d/DrawablePath2D.svg")
	)
	add_custom_type(
		"ScalableVectorShape2D",
		"Node2D",
		preload("res://addons/curved_lines_2d/scalable_vector_shape_2d.gd"),
		preload("res://addons/curved_lines_2d/DrawablePath2D.svg")
	)
	undo_redo = get_undo_redo()
	add_control_to_bottom_panel(scalable_vector_shapes_2d_dock as Control, "Scalable Vector Shapes 2D")
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	undo_redo.version_changed.connect(update_overlays)
	make_bottom_panel_item_visible(scalable_vector_shapes_2d_dock)

	set_global_position_popup_panel = preload("res://addons/curved_lines_2d/set_global_position_popup_panel.tscn").instantiate()
	arc_settings_popup_panel = preload("res://addons/curved_lines_2d/arc_settings_popup_panel.tscn").instantiate()
	EditorInterface.get_base_control().add_child(set_global_position_popup_panel)
	EditorInterface.get_base_control().add_child(arc_settings_popup_panel)
	if not set_global_position_popup_panel.value_changed.is_connected(_on_global_position_for_handle_changed):
		set_global_position_popup_panel.value_changed.connect(_on_global_position_for_handle_changed)
	if not set_global_position_popup_panel.visibility_changed.is_connected(_commit_undo_redo_transaction):
		set_global_position_popup_panel.visibility_changed.connect(_commit_undo_redo_transaction)

	if not scalable_vector_shapes_2d_dock.shape_created.is_connected(_on_shape_created):
		scalable_vector_shapes_2d_dock.shape_created.connect(_on_shape_created)
	if not scalable_vector_shapes_2d_dock.set_shape_preview.is_connected(_on_shape_preview):
		scalable_vector_shapes_2d_dock.set_shape_preview.connect(_on_shape_preview)
	if not scalable_vector_shapes_2d_dock.edit_tab.rect_created.is_connected(_on_rect_created):
		scalable_vector_shapes_2d_dock.edit_tab.rect_created.connect(_on_rect_created)
	if not scalable_vector_shapes_2d_dock.edit_tab.ellipse_created.is_connected(_on_ellipse_created):
		scalable_vector_shapes_2d_dock.edit_tab.ellipse_created.connect(_on_ellipse_created)


func select_node_reversibly(target_node : Node) -> void:
	if is_instance_valid(target_node):
		EditorInterface.edit_node(target_node)


func _on_shape_preview(curve : Curve2D):
	shape_preview = curve
	update_overlays()


func _on_rect_created(width : float, height : float, rx : float, ry : float, scene_root : Node2D) -> void:
	var new_rect := ScalableVectorShape2D.new()
	new_rect.shape_type = ScalableVectorShape2D.ShapeType.RECT
	new_rect.size = Vector2(width, height)
	new_rect.rx = rx
	new_rect.ry = ry
	_create_shape(new_rect, scene_root, "Rectangle")


func _on_ellipse_created(rx : float, ry : float, scene_root : Node2D) -> void:
	var new_ellipse := ScalableVectorShape2D.new()
	new_ellipse.shape_type = ScalableVectorShape2D.ShapeType.ELLIPSE
	new_ellipse.size = Vector2(rx * 2, ry * 2)
	_create_shape(new_ellipse, scene_root, "Ellipse")


func _on_shape_created(curve : Curve2D, scene_root : Node2D, node_name : String) -> void:
	var new_shape := ScalableVectorShape2D.new()
	new_shape.curve = curve
	_create_shape(new_shape, scene_root, node_name)


func _create_shape(new_shape : Node2D, scene_root : Node2D, node_name : String, is_cutout_for : ScalableVectorShape2D = null) -> void:
	var current_selection := EditorInterface.get_selection().get_selected_nodes().pop_back()
	var parent = current_selection if current_selection is Node2D else scene_root
	new_shape.name = node_name
	if not is_instance_valid(is_cutout_for):
		new_shape.position = _get_viewport_center() if parent == scene_root else Vector2.ZERO
	undo_redo.create_action("Add a %s to the scene " % node_name)
	undo_redo.add_do_method(parent, 'add_child', new_shape, true)
	undo_redo.add_do_method(new_shape, 'set_owner', scene_root)
	undo_redo.add_do_reference(new_shape)
	undo_redo.add_undo_method(parent, 'remove_child', new_shape)
	if is_instance_valid(is_cutout_for):
		var new_clip_paths := is_cutout_for.clip_paths.duplicate()
		new_clip_paths.append(new_shape)
		undo_redo.add_do_property(is_cutout_for, 'clip_paths', new_clip_paths)
		undo_redo.add_undo_property(is_cutout_for, 'clip_paths', is_cutout_for.clip_paths)
	else:
		for draw_fn in PAINT_ORDER_MAP[_get_default_paint_order()]:
			call(draw_fn, new_shape, scene_root)
	undo_redo.add_do_method(self, 'select_node_reversibly', new_shape)
	undo_redo.add_undo_method(self, 'select_node_reversibly', parent)
	undo_redo.commit_action()


func _add_fill_to_created_shape(new_shape : ScalableVectorShape2D, scene_root : Node2D) -> void:
	if _is_add_fill_enabled():
		var polygon := Polygon2D.new()
		polygon.name = "Fill"
		polygon.color = _get_default_fill_color()
		undo_redo.add_do_property(new_shape, 'polygon', polygon)
		undo_redo.add_do_method(new_shape, 'add_child', polygon, true)
		undo_redo.add_do_method(polygon, 'set_owner', scene_root)
		undo_redo.add_do_reference(polygon)
		undo_redo.add_undo_method(new_shape, 'remove_child', polygon)


func _add_stroke_to_created_shape(new_shape : ScalableVectorShape2D, scene_root : Node2D) -> void:
	if _is_add_stroke_enabled():
		var line := Line2D.new()
		line.name = "Stroke"
		line.default_color = _get_default_stroke_color()
		line.width = _get_default_stroke_width()
		line.begin_cap_mode = _get_default_begin_cap()
		line.end_cap_mode = _get_default_end_cap()
		line.joint_mode = _get_default_joint_mode()
		line.sharp_limit = 90.0
		undo_redo.add_do_property(new_shape, 'line', line)
		undo_redo.add_do_method(new_shape, 'add_child', line, true)
		undo_redo.add_do_method(line, 'set_owner', scene_root)
		undo_redo.add_do_reference(line)
		undo_redo.add_undo_method(new_shape, 'remove_child', line)


func _add_collision_to_created_shape(new_shape : ScalableVectorShape2D, scene_root : Node2D) -> void:
	if _add_collision_object_type() != ScalableVectorShape2D.CollisionObjectType.NONE:
		var collision : CollisionObject2D = null
		match  _add_collision_object_type():
			ScalableVectorShape2D.CollisionObjectType.STATIC_BODY_2D:
				collision = StaticBody2D.new()
			ScalableVectorShape2D.CollisionObjectType.AREA_2D:
				collision = Area2D.new()
			ScalableVectorShape2D.CollisionObjectType.ANIMATABLE_BODY_2D:
				collision = AnimatableBody2D.new()
			ScalableVectorShape2D.CollisionObjectType.RIGID_BODY_2D:
				collision = RigidBody2D.new()
			ScalableVectorShape2D.CollisionObjectType.CHARACTER_BODY_2D:
				collision = CharacterBody2D.new()
			ScalableVectorShape2D.CollisionObjectType.PHYSICAL_BONE_2D:
				collision = PhysicalBone2D.new()
		undo_redo.add_do_method(new_shape, 'add_child', collision, true)
		undo_redo.add_do_reference(collision)
		undo_redo.add_do_method(collision, 'set_owner', scene_root)
		undo_redo.add_do_property(new_shape, 'collision_object', collision)
		undo_redo.add_undo_method(new_shape, 'remove_child', collision)


func _on_selection_changed():
	var scene_root := EditorInterface.get_edited_scene_root()
	if _is_editing_enabled() and is_instance_valid(scene_root):
		# inelegant fix to always keep an instance of Node selected, so
		# _forward_canvas_gui_input will still be called upon losing focus
		if (not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
				and EditorInterface.get_selection().get_selected_nodes().is_empty()):
			EditorInterface.edit_node(scene_root)
		var current_selection := EditorInterface.get_selection().get_selected_nodes().pop_back()

	update_overlays()


func _handles(object: Object) -> bool:
	return object is Node


func _find_scalable_vector_shape_2d_nodes() -> Array[Node]:
	var scene_root := EditorInterface.get_edited_scene_root()
	if is_instance_valid(scene_root):
		var result := scene_root.find_children("*", "ScalableVectorShape2D")
		if scene_root is ScalableVectorShape2D:
			result.push_front(scene_root)
		return result
	return []


func _find_scalable_vector_shape_2d_nodes_at(pos : Vector2) -> Array[Node]:
	if is_instance_valid(EditorInterface.get_edited_scene_root()):
		return (_find_scalable_vector_shape_2d_nodes()
					.filter(func(x : ScalableVectorShape2D): return not x.has_meta("_edit_lock_"))
					.filter(func(x : ScalableVectorShape2D): return x.is_visible_in_tree())
					.filter(func(x : ScalableVectorShape2D): return x.owner == EditorInterface.get_edited_scene_root())
					.filter(func(x : ScalableVectorShape2D): return x.has_point(pos))
		)
	return []


func _is_change_pivot_button_active() -> bool:
	var results = (
			EditorInterface.get_editor_viewport_2d().find_parent("*CanvasItemEditor*")
					.find_children("*Button*", "", true, false)
	)
	if results.size() >= 6:
		return results[5].button_pressed
	return false


func _get_select_mode_button() -> Button:
	if is_instance_valid(select_mode_button):
		return select_mode_button
	else:
		select_mode_button = (
			EditorInterface.get_editor_viewport_2d().find_parent("*CanvasItemEditor*")
					.find_child("*Button*", true, false)
		)
		return select_mode_button


func _get_viewport_center() -> Vector2:
	var tr := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var og := tr.get_origin()
	var sz := Vector2(EditorInterface.get_editor_viewport_2d().size)
	return (sz / 2) / tr.get_scale() - og / tr.get_scale()


func _vp_transform(p : Vector2) -> Vector2:
	var s := EditorInterface.get_editor_viewport_2d().get_final_transform().get_scale()
	var o := EditorInterface.get_editor_viewport_2d().get_final_transform().get_origin()
	return (p * s) + o


func _is_svs_valid(svs : Object) -> bool:
	return is_instance_valid(svs) and svs is ScalableVectorShape2D and svs.curve


func _get_hovered_handle_metadata(svs : ScalableVectorShape2D) -> Dictionary:

	if svs.has_meta(META_NAME_HOVER_POINT_IDX):
		return {
			'global_pos': svs.to_global(svs.curve.get_point_position(
				svs.get_meta(META_NAME_HOVER_POINT_IDX)
			)),
			'meta_name': META_NAME_HOVER_POINT_IDX,
			'point_idx': svs.get_meta(META_NAME_HOVER_POINT_IDX)
		}
	elif svs.has_meta(META_NAME_HOVER_CP_IN_IDX):
		return {
			'global_pos': svs.to_global(svs.curve.get_point_position(
				svs.get_meta(META_NAME_HOVER_CP_IN_IDX)
			) + svs.curve.get_point_in(
				svs.get_meta(META_NAME_HOVER_CP_IN_IDX)
			)),
			'meta_name': META_NAME_HOVER_CP_IN_IDX,
			'point_idx': svs.get_meta(META_NAME_HOVER_CP_IN_IDX)
		}
	elif svs.has_meta(META_NAME_HOVER_CP_OUT_IDX):
		return {
			'global_pos': svs.to_global(svs.curve.get_point_position(
				svs.get_meta(META_NAME_HOVER_CP_OUT_IDX)
			) + svs.curve.get_point_out(
				svs.get_meta(META_NAME_HOVER_CP_OUT_IDX)
			)),
			'meta_name': META_NAME_HOVER_CP_OUT_IDX,
			'point_idx': svs.get_meta(META_NAME_HOVER_CP_OUT_IDX)
		}
	return {}


func _curve_control_has_hover(svs : ScalableVectorShape2D) -> bool:
	return (
		svs.has_meta(META_NAME_HOVER_POINT_IDX) or
		svs.has_meta(META_NAME_HOVER_CP_IN_IDX) or
		svs.has_meta(META_NAME_HOVER_CP_OUT_IDX)
	)


func _handle_has_hover(svs : ScalableVectorShape2D) -> bool:
	return (
		svs.has_meta(META_NAME_HOVER_POINT_IDX) or
		svs.has_meta(META_NAME_HOVER_CP_IN_IDX) or
		svs.has_meta(META_NAME_HOVER_CP_OUT_IDX) or
		svs.has_meta(META_NAME_HOVER_GRADIENT_FROM) or
		svs.has_meta(META_NAME_HOVER_GRADIENT_TO) or
		svs.has_meta(META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX)
	)


func _draw_control_point_handle(viewport_control : Control, svs : ScalableVectorShape2D,
		handle : Dictionary, prefix : String, is_hovered : bool, self_is_hovered : bool) -> String:
	if handle[prefix].length():
		var color := VIEWPORT_ORANGE if is_hovered else Color.WHITE
		var width := 2 if is_hovered else 1
		viewport_control.draw_line(_vp_transform(handle['point_position']),
				_vp_transform(handle[prefix + '_position']), Color.WEB_GRAY, 1, true)
		viewport_control.draw_circle(_vp_transform(handle[prefix + '_position']), 5, Color.DIM_GRAY)
		viewport_control.draw_circle(_vp_transform(handle[prefix + '_position']), 5, color, false, width)
		if self_is_hovered:
			var hint_txt := "Control point " + prefix
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				hint_txt += "\n - Drag to move\n - Right click to delete"
				hint_txt += "\n - Hold Shift + Drag to move mirrored"
			if Input.is_key_pressed(KEY_ALT):
				hint_txt += "\n - Click to set exact global position (Alt held)"
			else:
				hint_txt += "\n - Alt + Click to set exact global position"
			return hint_txt
	return ""


func _draw_rect_control_point_handle(viewport_control : Control, svs : ScalableVectorShape2D,
		handle : Dictionary, prefix : String, is_hovered : bool) -> String:
	var prop_name := "rx" if prefix == "in" else "ry"
	var color := VIEWPORT_ORANGE if is_hovered else Color.WHITE
	var width := 2 if is_hovered else 1
	viewport_control.draw_line(_vp_transform(svs.to_global(svs.get_bounding_rect().position)),
			_vp_transform(handle[prefix + '_position']), Color.WEB_GRAY, 1, true)
	viewport_control.draw_circle(_vp_transform(handle[prefix + '_position']), 5, Color.DIM_GRAY)
	viewport_control.draw_circle(_vp_transform(handle[prefix + '_position']), 5, color, false, width)
	if is_hovered:
		var hint_txt := "Control point rounded corners "
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var dir := "right / left" if prefix == 'in' else "up / down"
			hint_txt += "\n - Drag %s to move \n - Right click to remove rounded corners" % dir
			hint_txt += "\n - Hold Shift + Drag to drag only this handle"
		return hint_txt
	return ""


func _draw_hint(viewport_control : Control, txt : String, force_draw := false) -> void:
	if set_global_position_popup_panel.visible:
		return
	if not _get_select_mode_button().button_pressed:
		return
	if not _are_hints_enabled() and not force_draw:
		return

	var txt_pos := (_vp_transform(EditorInterface.get_editor_viewport_2d().get_mouse_position())
		+ Vector2(15, 8))
	var lines := txt.split("\n")
	for i in range(lines.size()):
		var text := lines[i]
		var pos := txt_pos + Vector2.DOWN * (i * (ThemeDB.fallback_font_size + ThemeDB.fallback_font_size * .2))
		viewport_control.draw_string_outline(ThemeDB.fallback_font, pos, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, ThemeDB.fallback_font_size, 3, Color.BLACK)
		viewport_control.draw_string(ThemeDB.fallback_font, pos, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, ThemeDB.fallback_font_size, Color.WHITE_SMOKE)


func _draw_point_number(viewport_control: Control, p : Vector2, text : String) -> void:
	if not _am_showing_point_numbers():
		return
	var pos := _vp_transform(p)
	var width := 8 * (text.length() + 1)
	viewport_control.draw_string_outline(ThemeDB.fallback_font, pos +  + Vector2(-width, 6), text,
		HORIZONTAL_ALIGNMENT_LEFT, width, ThemeDB.fallback_font_size, 3, Color.BLACK)
	viewport_control.draw_string(ThemeDB.fallback_font, pos + Vector2(-width, 6), text,
		HORIZONTAL_ALIGNMENT_LEFT, width, ThemeDB.fallback_font_size, Color.WHITE_SMOKE)


func _draw_handles(viewport_control : Control, svs : ScalableVectorShape2D) -> void:
	if not _get_select_mode_button().button_pressed:
		return
	var hint_txt := ""
	var point_txt := ""
	var point_pos_txt := ""
	var point_hint_pos := Vector2.ZERO
	var handles = svs.get_curve_handles()
	for i in range(handles.size()):
		var handle = handles[i]

		var is_hovered : bool = svs.get_meta(META_NAME_HOVER_POINT_IDX, -1) == i
		var cp_in_is_hovered : bool = svs.get_meta(META_NAME_HOVER_CP_IN_IDX, -1) == i
		var cp_out_is_hovered : bool = svs.get_meta(META_NAME_HOVER_CP_OUT_IDX, -1) == i
		var color := VIEWPORT_ORANGE if is_hovered else Color.WHITE
		var width := 2 if is_hovered else 1
		if is_hovered:
			point_pos_txt = "Global point position: (%.3f, %.3f)" % [handle["point_position"].x, handle["point_position"].y]
		elif cp_in_is_hovered:
			point_pos_txt = "Global curve handle position: (%.3f, %.3f)" % [handle["in_position"].x,handle["in_position"].y]
		elif cp_out_is_hovered:
			point_pos_txt = "Global curve handle position: (%.3f, %.3f)" % [handle["out_position"].x, handle["out_position"].y]

		if svs.shape_type == ScalableVectorShape2D.ShapeType.RECT:
			hint_txt += _draw_rect_control_point_handle(viewport_control, svs, handle, 'in',
					cp_in_is_hovered)
			if handle['out'].length():
				hint_txt += _draw_rect_control_point_handle(viewport_control, svs, handle, 'out',
						cp_out_is_hovered)
		elif svs.shape_type == ScalableVectorShape2D.ShapeType.PATH:
			if not svs.is_arc_start(i - 1):
				hint_txt += _draw_control_point_handle(viewport_control, svs, handle, 'in',
						is_hovered or cp_in_is_hovered, cp_in_is_hovered)
			if not svs.is_arc_start(i):
				hint_txt +=_draw_control_point_handle(viewport_control, svs, handle, 'out',
						is_hovered or cp_out_is_hovered, cp_out_is_hovered)

		if handle['mirrored']:
			# mirrored handles
			var rect := Rect2(_vp_transform(handle['point_position']) - Vector2(5, 5), Vector2(10, 10))
			viewport_control.draw_rect(rect, Color.DIM_GRAY, .5)
			viewport_control.draw_rect(rect, color, false, width)
		else:
			# unmirrored handles / zero length handles
			var p1 := _vp_transform(handle['point_position'])
			var pts := PackedVector2Array([
					Vector2(p1.x - 8, p1.y), Vector2(p1.x, p1.y - 8),
					Vector2(p1.x + 8, p1.y), Vector2(p1.x, p1.y + 8)
			])
			viewport_control.draw_polygon(pts, [Color.DIM_GRAY])
			pts.append(Vector2(p1.x - 8, p1.y))
			viewport_control.draw_polyline(pts, color, width)

		if is_hovered:
			if svs.shape_type == ScalableVectorShape2D.ShapeType.PATH:
				point_txt = str(i) + handle['is_closed']
				point_hint_pos = handle['point_position']
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if Input.is_key_pressed(KEY_SHIFT) and svs.shape_type == ScalableVectorShape2D.ShapeType.PATH:
					hint_txt += " - Release mouse to set curve handles"
			else:
				if svs.shape_type == ScalableVectorShape2D.ShapeType.RECT:
					hint_txt += " - Drag to resize rectange"
				elif svs.shape_type == ScalableVectorShape2D.ShapeType.ELLIPSE:
					hint_txt += " - Drag to resize ellipse"
				else:
					hint_txt += " - Drag to move"
				if handle['is_closed'].length() > 0:
					hint_txt += "\n - Double click to break loop"
				elif svs.shape_type == ScalableVectorShape2D.ShapeType.PATH:
					hint_txt += "\n - Right click to delete"
					if not svs.is_curve_closed() and (
						(i == 0 and handles.size() > 2) or
						(i == handles.size() - 1 and i > 1)
					):
						hint_txt += "\n - Double click to close loop"
				if svs.shape_type == ScalableVectorShape2D.ShapeType.PATH:
					hint_txt += "\n - Hold Shift + Drag to create curve handles"
					if Input.is_key_pressed(KEY_ALT):
						hint_txt += "\n - Click to set exact global position (Alt held)"
					else:
						hint_txt += "\n - Alt + Click to set exact global position"


	var gradient_handles := svs.get_gradient_handles()
	if not gradient_handles.is_empty():
		var p1 := _vp_transform(gradient_handles['fill_from_pos'])
		var p2 := _vp_transform(gradient_handles['fill_to_pos'])
		var hint_color := svs.shape_hint_color if svs.shape_hint_color else Color.LIME_GREEN

		if svs.has_meta(META_NAME_HOVER_GRADIENT_FROM):
			hint_txt = "- Drag to move gradient start position"
			viewport_control.draw_circle(p1, 16, hint_color)
			viewport_control.draw_circle(p1, 12, Color.WHITE, false, 0.5, true)
		if svs.has_meta(META_NAME_HOVER_GRADIENT_TO):
			hint_txt = "- Drag to move gradient end position"
			viewport_control.draw_circle(p2, 16, hint_color)
			viewport_control.draw_circle(p2, 12, Color.WHITE, false, 0.5, true)

		for p : Vector2 in gradient_handles['stop_positions']:
			viewport_control.draw_circle(_vp_transform(p) + Vector2(1,1), 5, Color(0.0,0.0,0.0, 0.4), true, -1, true)

		viewport_control.draw_line(p1, p2, hint_color, .5, true)

		for idx in range(gradient_handles['stop_positions'].size()):
			var p := _vp_transform(gradient_handles['stop_positions'][idx])
			var color := (Color.WHITE
					if svs.get_meta(META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX, -1) == idx
					else Color.WEB_GRAY)
			viewport_control.draw_circle(p, 5, gradient_handles["stop_colors"][idx])
			viewport_control.draw_circle(p, 5, color, false, 0.5, true)

		var p1_color := Color.WHITE if svs.has_meta(META_NAME_HOVER_GRADIENT_FROM) else hint_color
		var p2_color := Color.WHITE if svs.has_meta(META_NAME_HOVER_GRADIENT_TO) else hint_color
		_draw_crosshair(viewport_control, p1 , 8, 8, p1_color, 1)
		_draw_crosshair(viewport_control, p2 , 8, 8, p2_color, 1)
		if svs.has_meta(META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX):
			hint_txt = "- Drag to move color stop\n- Right click to remove color stop"
		if (svs.has_meta(META_NAME_HOVER_CLOSEST_POINT_ON_GRADIENT_LINE)
				and not Input.is_key_pressed(KEY_CTRL)
				and not Input.is_key_pressed(KEY_SHIFT)):
			_draw_crosshair(viewport_control, svs.get_meta(META_NAME_HOVER_CLOSEST_POINT_ON_GRADIENT_LINE))
			hint_txt = "- Double click to add color stop here"
	if not point_txt.is_empty():
		_draw_point_number(viewport_control, point_hint_pos, point_txt)

	if not _are_hints_enabled() and _am_showing_point_numbers():
		_draw_hint(viewport_control, point_pos_txt, true)
	elif _are_hints_enabled() and _am_showing_point_numbers() and point_pos_txt.length():
		hint_txt += "\n\n - " + point_pos_txt

	if not hint_txt.is_empty():
		_draw_hint(viewport_control, hint_txt)



func _set_handle_hover(g_mouse_pos : Vector2, svs : ScalableVectorShape2D) -> void:
	var mouse_pos := _vp_transform(g_mouse_pos)
	var handles = svs.get_curve_handles()
	var gradient_handles = svs.get_gradient_handles()
	svs.remove_meta(META_NAME_HOVER_POINT_IDX)
	svs.remove_meta(META_NAME_HOVER_CP_IN_IDX)
	svs.remove_meta(META_NAME_HOVER_CP_OUT_IDX)
	svs.remove_meta(META_NAME_HOVER_GRADIENT_FROM)
	svs.remove_meta(META_NAME_HOVER_GRADIENT_TO)
	svs.remove_meta(META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX)
	svs.remove_meta(META_NAME_HOVER_CLOSEST_POINT_ON_GRADIENT_LINE)
	for i in range(handles.size()):
		var handle = handles[i]
		if mouse_pos.distance_to(_vp_transform(handle['point_position'])) < 10:
			svs.set_meta(META_NAME_HOVER_POINT_IDX, i)
		elif mouse_pos.distance_to(_vp_transform(handle['in_position'])) < 10:
			svs.set_meta(META_NAME_HOVER_CP_IN_IDX, i)
		elif mouse_pos.distance_to(_vp_transform(handle['out_position'])) < 10:
			svs.set_meta(META_NAME_HOVER_CP_OUT_IDX, i)
	if not gradient_handles.is_empty() and not _handle_has_hover(svs):
		var stop_idx = gradient_handles['stop_positions'].find_custom(func(p):
					return mouse_pos.distance_to(_vp_transform(p)) < 6)
		if stop_idx > -1:
			svs.set_meta(META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX, stop_idx)
		elif mouse_pos.distance_to(_vp_transform(gradient_handles['fill_from_pos'])) < 20:
			svs.set_meta(META_NAME_HOVER_GRADIENT_FROM, true)
		elif mouse_pos.distance_to(_vp_transform(gradient_handles['fill_to_pos'])) < 20:
			svs.set_meta(META_NAME_HOVER_GRADIENT_TO, true)
		else:
			var p := Geometry2D.get_closest_point_to_segment(mouse_pos,
					_vp_transform(gradient_handles['fill_from_pos']),
					_vp_transform(gradient_handles['fill_to_pos']))
			if mouse_pos.distance_to(p) < 10:
				svs.set_meta(META_NAME_HOVER_CLOSEST_POINT_ON_GRADIENT_LINE, p)

	var closest_point_on_curve := svs.get_closest_point_on_curve(g_mouse_pos)

	if mouse_pos.distance_to(_vp_transform(closest_point_on_curve.point_position)) < 15:
		svs.set_meta(META_NAME_HOVER_CLOSEST_POINT, closest_point_on_curve)


func _draw_curve(viewport_control : Control, svs : ScalableVectorShape2D,
		is_selected := true) -> void:
	var points = svs.get_poly_points().map(_vp_transform)
	var color := svs.shape_hint_color if svs.shape_hint_color else Color.LIME_GREEN
	if not is_selected:
		color = Color(0.5, 0.5, 0.5, 0.2)
	var last_p := Vector2.INF
	for p : Vector2 in points:
		if last_p != Vector2.INF:
			viewport_control.draw_line(last_p, p, color, 1.0, is_selected)
		last_p = p
	if is_instance_valid(svs.line) and svs.line.closed and points.size() > 1:
		viewport_control.draw_dashed_line(last_p, points[0], color, 1, 5.0, true, true)


func _draw_crosshair(viewport_control : Control, p : Vector2, orbit := 2.0, outer_orbit := 6.0,
	color := Color.WHITE, width := 1) -> void:
	if not _get_select_mode_button().button_pressed:
		return
	var line_len = outer_orbit + orbit
	viewport_control.draw_line(p - line_len * Vector2.UP, p - orbit * Vector2.UP, Color.WEB_GRAY, width + 1)
	viewport_control.draw_line(p - line_len * Vector2.RIGHT, p - orbit * Vector2.RIGHT, Color.WEB_GRAY, width + 1)
	viewport_control.draw_line(p - line_len * Vector2.DOWN, p - orbit * Vector2.DOWN, Color.WEB_GRAY, width + 1)
	viewport_control.draw_line(p - line_len * Vector2.LEFT, p - orbit * Vector2.LEFT, Color.WEB_GRAY, width + 1)
	viewport_control.draw_line(p - line_len * Vector2.UP, p - orbit * Vector2.UP, color, width)
	viewport_control.draw_line(p - line_len * Vector2.RIGHT, p - orbit * Vector2.RIGHT, color, width)
	viewport_control.draw_line(p - line_len * Vector2.DOWN, p - orbit * Vector2.DOWN, color, width)
	viewport_control.draw_line(p - line_len * Vector2.LEFT, p - orbit * Vector2.LEFT, color, width)


func _draw_add_point_hint(viewport_control : Control, svs : ScalableVectorShape2D) -> void:
	var mouse_pos := EditorInterface.get_editor_viewport_2d().get_mouse_position()
	var p := _vp_transform(mouse_pos)
	if Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_SHIFT):
		if svs.has_fine_point(mouse_pos):
			_draw_crosshair(viewport_control, p)
			_draw_hint(viewport_control, "- Click to start a cutout shape here (Ctrl+Shift held)")
		else:
			_draw_hint(viewport_control, "- Start a cutout shape while hovering over selected shape (Ctrl+Shift held)")
	elif Input.is_key_pressed(KEY_CTRL):
		_draw_crosshair(viewport_control, p)
		_draw_hint(viewport_control, "- Click to add point here (Ctrl held)")
	elif Input.is_key_pressed(KEY_SHIFT):
		_draw_hint(viewport_control, "- Use mousewheel to resize shape (Shift held)")
	elif not svs.has_meta(META_NAME_HOVER_CLOSEST_POINT_ON_GRADIENT_LINE):
		var hint := "- Hold Ctrl to add points to selected shape
				- Hold Shift to resize shape with mouswheel"
		if svs.has_fine_point(mouse_pos):
			hint += "\n- Hold Ctrl-Shift to start a cutout shape here"
		_draw_hint(viewport_control, hint)


func _draw_closest_point_on_curve(viewport_control : Control, svs : ScalableVectorShape2D) -> void:
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT):
		_draw_add_point_hint(viewport_control, svs)
		return

	if svs.has_meta(META_NAME_HOVER_CLOSEST_POINT):
		var hint := ""
		var md_p : ClosestPointOnCurveMeta = svs.get_meta(META_NAME_HOVER_CLOSEST_POINT)
		if svs.is_arc_start(md_p.before_segment - 1):
			var arc_start_idx := md_p.before_segment - 1
			var arc := svs.arc_list.get_arc_for_point(arc_start_idx)
			var arc_points := Array(svs.tessellate_arc_segment(
				svs.curve.get_point_position(arc_start_idx),
				arc.radius, arc.rotation_deg, arc.large_arc_flag, arc.sweep_flag,
				svs.curve.get_point_position(arc_start_idx + 1),
			)).map(func(p): return _vp_transform(svs.to_global(p)))
			viewport_control.draw_polyline(arc_points, Color.RED, 3.0, true)
			hint = "- Left click to open arc settings"
			hint += "\n- Right click to remove arc (straighten this line segment)"
		else:
			var p = _vp_transform(md_p.point_position)
			_draw_crosshair(viewport_control, _vp_transform(md_p.point_position))
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if svs.curve.point_count > 1:
					hint = "- Double click to add point on the line"
					if md_p.before_segment < svs.curve.point_count:
						hint += "\n- Drag to change curve"
						hint += "\n- Right click to convert line segment to arc"
				else:
					_draw_add_point_hint(viewport_control, svs)
		if not hint.is_empty():
			_draw_hint(viewport_control, hint)


func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	if not _is_editing_enabled():
		return
	if not is_instance_valid(EditorInterface.get_edited_scene_root()):
		return
	var current_selection := EditorInterface.get_selection().get_selected_nodes().pop_back()
	var all_valid_svs_nodes := _find_scalable_vector_shape_2d_nodes().filter(_is_svs_valid)
	for result : ScalableVectorShape2D in all_valid_svs_nodes:
		if result == current_selection:
			viewport_control.draw_polyline(result.get_bounding_box().map(_vp_transform),
					VIEWPORT_ORANGE, 2.0)
			_draw_curve(viewport_control, result)
			_draw_handles(viewport_control, result)
			if not _handle_has_hover(result) and result.shape_type == ScalableVectorShape2D.ShapeType.PATH:
				if result.has_meta(META_NAME_HOVER_CLOSEST_POINT):
					_draw_closest_point_on_curve(viewport_control, result)
				else:
					_draw_add_point_hint(viewport_control, result)

		elif result.has_meta(META_NAME_SELECT_HINT):
			viewport_control.draw_polyline(result.get_bounding_box().map(_vp_transform),
					Color.WEB_GRAY, 1.0)

		if not(result.line or result.collision_polygon or result.polygon):
			_draw_curve(viewport_control, result, false)

	if shape_preview:
		var points := Array(shape_preview.tessellate())
		var pos = _get_viewport_center()
		var stroke_width = (_get_default_stroke_width() * EditorInterface.get_editor_viewport_2d()
				.get_final_transform().get_scale().x)
		if _is_svs_valid(current_selection):
			points = points.map(current_selection.to_global)
			pos = Vector2.ZERO
			stroke_width *= current_selection.global_scale.x
		points = points.map(func(p): return p + pos).map(_vp_transform)
		match _get_default_paint_order():
			PaintOrder.MARKERS_STROKE_FILL, PaintOrder.STROKE_FILL_MARKERS, PaintOrder.STROKE_MARKERS_FILL:
				if _is_add_stroke_enabled():
					viewport_control.draw_polyline(points, _get_default_stroke_color(), stroke_width)
				if _is_add_fill_enabled():
					viewport_control.draw_polygon(points, [_get_default_fill_color()])
			PaintOrder.MARKERS_FILL_STROKE, PaintOrder.FILL_STROKE_MARKERS, PaintOrder.FILL_MARKERS_STROKE, _:
				if _is_add_fill_enabled():
					viewport_control.draw_polygon(points, [_get_default_fill_color()])
				if _is_add_stroke_enabled():
					viewport_control.draw_polyline(points, _get_default_stroke_color(), stroke_width)

		if not _is_add_fill_enabled() and not _is_add_stroke_enabled():
			viewport_control.draw_polyline(points, Color.LIME, 1)


func _start_undo_redo_transaction(name := "") -> void:
	in_undo_redo_transaction = true
	undo_redo_transaction = {
		UndoRedoEntry.NAME: name,
		UndoRedoEntry.DOS: [],
		UndoRedoEntry.UNDOS: [],
		UndoRedoEntry.DO_PROPS: [],
		UndoRedoEntry.UNDO_PROPS : []
	}

func _commit_undo_redo_transaction() -> void:
	if not in_undo_redo_transaction:
		return
	in_undo_redo_transaction = false
	undo_redo.create_action(undo_redo_transaction[UndoRedoEntry.NAME])
	for undo_method in undo_redo_transaction[UndoRedoEntry.UNDOS]:
		undo_redo.callv('add_undo_method', undo_method)
	for undo_prop in undo_redo_transaction[UndoRedoEntry.UNDO_PROPS]:
		undo_redo.callv('add_undo_property', undo_prop)
	for do_method in undo_redo_transaction[UndoRedoEntry.DOS]:
		undo_redo.callv('add_do_method', do_method)
	for do_prop in undo_redo_transaction[UndoRedoEntry.DO_PROPS]:
		undo_redo.callv('add_do_property', do_prop)
	undo_redo.commit_action(false)
	undo_redo_transaction = {
		UndoRedoEntry.NAME: name,
		UndoRedoEntry.DOS: [],
		UndoRedoEntry.UNDOS: [],
		UndoRedoEntry.UNDO_PROPS: [],
		UndoRedoEntry.DO_PROPS: []
	}


func _on_global_position_for_handle_changed(global_pos : Vector2, meta_name: String, idx : int) -> void:
	var cur := EditorInterface.get_selection().get_selected_nodes().pop_back()
	if _is_svs_valid(cur):
		match(meta_name):
			META_NAME_HOVER_CP_IN_IDX:
				_update_curve_cp_in_position(cur, global_pos, idx)
			META_NAME_HOVER_CP_OUT_IDX:
				_update_curve_cp_out_position(cur, global_pos, idx)
			META_NAME_HOVER_POINT_IDX:
				_update_curve_point_position(cur, global_pos, idx)
		update_overlays()

func _update_curve_point_position(current_selection : ScalableVectorShape2D, mouse_pos : Vector2, idx : int) -> void:
	if not in_undo_redo_transaction:
		_start_undo_redo_transaction("Move point on " + str(current_selection))
		if idx == 0 and current_selection.is_curve_closed():
			var idx_1 = current_selection.curve.point_count - 1
			undo_redo_transaction[UndoRedoEntry.UNDOS].append([
				current_selection.curve, 'set_point_position', idx_1, current_selection.curve.get_point_position(idx_1)
			])
		undo_redo_transaction[UndoRedoEntry.UNDOS].append([
			current_selection.curve, 'set_point_position', idx, current_selection.curve.get_point_position(idx)
		])

	undo_redo_transaction[UndoRedoEntry.DOS] = []
	if idx == 0 and current_selection.is_curve_closed():
		var idx_1 = current_selection.curve.point_count - 1
		undo_redo_transaction[UndoRedoEntry.DOS].append([
				current_selection, 'set_global_curve_point_position', mouse_pos, idx_1,
				_is_snapped_to_pixel(), _get_snap_resolution()
		])
		current_selection.set_global_curve_point_position(mouse_pos, idx_1,
				_is_snapped_to_pixel(), _get_snap_resolution())
	undo_redo_transaction[UndoRedoEntry.DOS].append([
			current_selection, 'set_global_curve_point_position', mouse_pos, idx,
			_is_snapped_to_pixel(), _get_snap_resolution()
	])
	current_selection.set_global_curve_point_position(mouse_pos, idx,
			_is_snapped_to_pixel(), _get_snap_resolution())


func _update_rect_dimensions(svs : ScalableVectorShape2D, mouse_pos : Vector2) -> void:
	if not in_undo_redo_transaction:
		_start_undo_redo_transaction("Change rect size on " + str(svs))
		undo_redo_transaction[UndoRedoEntry.UNDO_PROPS] = [[svs, 'size', svs.size]]
	svs.size = svs.to_local(mouse_pos) - svs.get_bounding_rect().position
	undo_redo_transaction[UndoRedoEntry.DO_PROPS] = [[svs, 'size', svs.size]]


func _update_rect_corner_radius(svs : ScalableVectorShape2D, mouse_pos : Vector2, prop_name : String, is_symmetrical : bool) -> void:
	if not in_undo_redo_transaction:
		_start_undo_redo_transaction("Change rect " + prop_name + " on " + str(svs))
		undo_redo_transaction[UndoRedoEntry.UNDO_PROPS] = [
			[svs, 'rx', svs.rx], [svs, 'ry', svs.ry]
		]
	if prop_name == 'rx':
		svs.rx = svs.to_local(mouse_pos).x - svs.get_bounding_rect().position.x
		if is_symmetrical:
			svs.ry = svs.rx
	if prop_name == 'ry':
		svs.ry = svs.to_local(mouse_pos).y - svs.get_bounding_rect().position.y
		if is_symmetrical:
			svs.rx = svs.ry

	undo_redo_transaction[UndoRedoEntry.DO_PROPS] = [
		[svs, 'rx', svs.rx],
		[svs, 'ry', svs.ry]
	]


func _update_curve_cp_in_position(current_selection : ScalableVectorShape2D, mouse_pos : Vector2, idx : int) -> void:
	if idx == 0:
		idx = current_selection.curve.point_count - 1

	var cp_in_is_cp_out_of_loop_start := (Input.is_key_pressed(KEY_SHIFT) and
			not(idx == current_selection.curve.point_count - 1
					and not current_selection.is_curve_closed())
	)
	if not in_undo_redo_transaction:
		_start_undo_redo_transaction("Move control point in %d on %s" % [idx, current_selection])
		undo_redo_transaction[UndoRedoEntry.UNDOS].append([current_selection.curve, 'set_point_in', idx, current_selection.curve.get_point_in(idx)])
		if cp_in_is_cp_out_of_loop_start:
			var idx_1 = 0 if idx == current_selection.curve.point_count - 1 else idx
			undo_redo_transaction[UndoRedoEntry.UNDOS].append([current_selection.curve, 'set_point_out', idx_1, current_selection.curve.get_point_out(idx_1)])

	current_selection.set_global_curve_cp_in_position(mouse_pos, idx,
			_is_snapped_to_pixel(), _get_snap_resolution())
	undo_redo_transaction[UndoRedoEntry.DOS] = [[
			current_selection, 'set_global_curve_cp_in_position', mouse_pos, idx,
			_is_snapped_to_pixel(), _get_snap_resolution()
	]]
	if cp_in_is_cp_out_of_loop_start:
		var idx_1 = 0 if idx == current_selection.curve.point_count - 1 else idx
		current_selection.curve.set_point_out(idx_1, -current_selection.curve.get_point_in(idx))
		undo_redo_transaction[UndoRedoEntry.DOS].append([current_selection.curve, 'set_point_out', idx_1, -current_selection.curve.get_point_in(idx)])


func _update_gradient_from_position(svs : ScalableVectorShape2D, mouse_pos : Vector2) -> void:
	if not in_undo_redo_transaction:
		_start_undo_redo_transaction("Move gradient from position for %s" % str(svs))
		undo_redo_transaction[UndoRedoEntry.UNDO_PROPS].append([svs.polygon.texture, 'fill_from',
				svs.polygon.texture.fill_from])
	var box := svs.get_bounding_rect()
	svs.polygon.texture.fill_from = (svs.to_local(mouse_pos) - box.position) / box.size
	undo_redo_transaction[UndoRedoEntry.DO_PROPS] = [[
		svs.polygon.texture, 'fill_from', svs.polygon.texture.fill_from
	]]


func _update_gradient_to_position(svs : ScalableVectorShape2D, mouse_pos : Vector2) -> void:
	if not in_undo_redo_transaction:
		_start_undo_redo_transaction("Move gradient from position for %s" % str(svs))
		undo_redo_transaction[UndoRedoEntry.UNDO_PROPS].append([svs.polygon.texture, 'fill_to',
				svs.polygon.texture.fill_to])
	var box := svs.get_bounding_rect()
	svs.polygon.texture.fill_to = (svs.to_local(mouse_pos) - box.position) / box.size
	undo_redo_transaction[UndoRedoEntry.DO_PROPS] = [[
		svs.polygon.texture, 'fill_to', svs.polygon.texture.fill_to
	]]


func _get_gradient_offset(svs : ScalableVectorShape2D, mouse_pos : Vector2) -> float:
	var box := svs.get_bounding_rect()
	var gradient_tex : GradientTexture2D = svs.polygon.texture
	var p := ((svs.to_local(mouse_pos) - box.position) / box.size)
	var p1 := Geometry2D.get_closest_point_to_segment(p, gradient_tex.fill_from, gradient_tex.fill_to)
	return p1.distance_to(gradient_tex.fill_from) / gradient_tex.fill_from.distance_to(gradient_tex.fill_to)


func _update_gradient_stop_color_pos(svs : ScalableVectorShape2D, mouse_pos : Vector2, idx : int) -> void:
	var new_offset := _get_gradient_offset(svs, mouse_pos)
	if not in_undo_redo_transaction:
		_start_undo_redo_transaction("Move gradient offset  %d on %s" % [idx, svs])
		undo_redo_transaction[UndoRedoEntry.UNDOS].append([svs.polygon.texture.gradient,
				'set_offset', idx, svs.polygon.texture.gradient.offsets[idx]])
	undo_redo_transaction[UndoRedoEntry.DOS] = [[
			svs.polygon.texture.gradient, 'set_offset', idx, new_offset
	]]
	svs.polygon.texture.gradient.set_offset(idx, new_offset)


func _add_color_stop(svs : ScalableVectorShape2D, mouse_pos : Vector2) -> void:
	var new_offset := _get_gradient_offset(svs, mouse_pos)
	var colors = Array(svs.polygon.texture.gradient.colors)
	var offsets = Array(svs.polygon.texture.gradient.offsets)
	var stops = {}
	for idx in range(colors.size()):
		stops[offsets[idx]] = colors[idx]
	stops[new_offset] = svs.polygon.texture.gradient.sample(new_offset)
	var stop_keys := stops.keys()
	stop_keys.sort()
	var new_colors = []
	var new_offsets = []
	for offset in stop_keys:
		new_colors.append(stops[offset])
		new_offsets.append(offset)

	undo_redo.create_action("Add color stop to %s " % str(svs))
	undo_redo.add_do_property(svs.polygon.texture.gradient, 'colors', new_colors)
	undo_redo.add_do_property(svs.polygon.texture.gradient, 'offsets', new_offsets)
	undo_redo.add_do_method(svs, 'notify_assigned_node_change')
	undo_redo.add_undo_property(svs.polygon.texture.gradient, 'colors', colors)
	undo_redo.add_undo_property(svs.polygon.texture.gradient, 'offsets', offsets)
	undo_redo.add_undo_method(svs, 'notify_assigned_node_change')
	undo_redo.commit_action()


func _remove_color_stop(svs : ScalableVectorShape2D, remove_idx : int) -> void:
	var colors = Array(svs.polygon.texture.gradient.colors)
	var offsets = Array(svs.polygon.texture.gradient.offsets)
	var stops = {}
	for idx in range(colors.size()):
		if idx != remove_idx:
			stops[offsets[idx]] = colors[idx]
	var stop_keys := stops.keys()
	stop_keys.sort()
	var new_colors = []
	var new_offsets = []
	for offset in stop_keys:
		new_colors.append(stops[offset])
		new_offsets.append(offset)

	undo_redo.create_action("Remove color stop from %s " % str(svs))
	undo_redo.add_do_property(svs.polygon.texture.gradient, 'colors', new_colors)
	undo_redo.add_do_property(svs.polygon.texture.gradient, 'offsets', new_offsets)
	undo_redo.add_do_method(svs, 'notify_assigned_node_change')
	undo_redo.add_undo_property(svs.polygon.texture.gradient, 'colors', colors)
	undo_redo.add_undo_property(svs.polygon.texture.gradient, 'offsets', offsets)
	undo_redo.add_undo_method(svs, 'notify_assigned_node_change')
	undo_redo.commit_action()

func _update_curve_cp_out_position(current_selection : ScalableVectorShape2D, mouse_pos : Vector2, idx : int) -> void:
	if idx == current_selection.curve.point_count - 1:
		idx = 0

	var cp_out_is_cp_in_of_loop_end := (Input.is_key_pressed(KEY_SHIFT)
			and not(idx == 0 and not current_selection.is_curve_closed()))
	if not in_undo_redo_transaction:
		_start_undo_redo_transaction("Move control point out %d on %s" % [idx, current_selection])
		undo_redo_transaction[UndoRedoEntry.UNDOS].append([current_selection.curve, 'set_point_out', idx, current_selection.curve.get_point_out(idx)])
		if cp_out_is_cp_in_of_loop_end:
			var idx_1 = current_selection.curve.point_count - 1 if idx == 0 else idx
			undo_redo_transaction[UndoRedoEntry.UNDOS].append([current_selection.curve, 'set_point_in', idx_1, current_selection.curve.get_point_in(idx_1)])

	current_selection.set_global_curve_cp_out_position(mouse_pos, idx,
			_is_snapped_to_pixel(), _get_snap_resolution())
	undo_redo_transaction[UndoRedoEntry.DOS] = [[
			current_selection, 'set_global_curve_cp_out_position', mouse_pos, idx,
			_is_snapped_to_pixel(), _get_snap_resolution()
	]]
	if cp_out_is_cp_in_of_loop_end:
		var idx_1 = current_selection.curve.point_count - 1 if idx == 0 else idx
		current_selection.curve.set_point_in(idx_1, -current_selection.curve.get_point_out(idx))
		undo_redo_transaction[UndoRedoEntry.DOS].append([current_selection.curve, 'set_point_in', idx_1, -current_selection.curve.get_point_out(idx)])


func _set_shape_origin(current_selection : ScalableVectorShape2D, mouse_pos : Vector2) -> void:
	undo_redo.create_action("Set origin on %s" % current_selection)
	undo_redo.add_do_method(current_selection, 'set_origin', mouse_pos)
	undo_redo.add_undo_method(current_selection, 'set_origin', current_selection.global_position)
	undo_redo.commit_action()


func _get_curve_backup(curve_in : Curve2D) -> Curve2D:
	var curve_copy := Curve2D.new()
	for i in range(curve_in.point_count):
		curve_copy.add_point(curve_in.get_point_position(i),
				curve_in.get_point_in(i), curve_in.get_point_out(i))
	return curve_copy


func _resize_shape(svs : ScalableVectorShape2D, s : float) -> void:
	if svs.shape_type == ScalableVectorShape2D.ShapeType.PATH:
		if not in_undo_redo_transaction:
			_start_undo_redo_transaction("Resize shape %s" % str(svs))
			undo_redo_transaction[UndoRedoEntry.UNDOS].append([
					svs, 'replace_curve_points', _get_curve_backup(svs.curve)])

		undo_redo_transaction[UndoRedoEntry.DOS] = []
		for idx in range(svs.curve.point_count):
			svs.curve.set_point_position(idx, svs.curve.get_point_position(idx) * s)
			svs.curve.set_point_in(idx, svs.curve.get_point_in(idx) * s)
			svs.curve.set_point_out(idx, svs.curve.get_point_out(idx) * s)
			undo_redo_transaction[UndoRedoEntry.DOS].append([svs.curve,
					'set_point_position', idx, svs.curve.get_point_position(idx) * s])
			undo_redo_transaction[UndoRedoEntry.DOS].append([svs.curve,
					'set_point_in', idx, svs.curve.get_point_in(idx) * s])
			undo_redo_transaction[UndoRedoEntry.DOS].append([svs.curve,
					'set_point_out', idx, svs.curve.get_point_out(idx) * s])
	else:
		if not in_undo_redo_transaction:
			_start_undo_redo_transaction("Resize shape %s" % str(svs))
			undo_redo_transaction[UndoRedoEntry.UNDO_PROPS] = [[svs, 'size', svs.size]]
		undo_redo_transaction[UndoRedoEntry.DO_PROPS] = [[svs, 'size', svs.size * s]]
		svs.size *= s


func _remove_point_from_curve(current_selection : ScalableVectorShape2D, idx : int) -> void:
	var orig_n := current_selection.curve.point_count
	if current_selection.is_curve_closed() and idx == 0:
		idx = orig_n - 1

	var backup := _get_curve_backup(current_selection.curve)
	undo_redo.create_action("Remove point %d from %s" % [idx, str(current_selection)])
	undo_redo.add_do_method(current_selection.curve, 'set_point_in', 0, Vector2.ZERO)
	if orig_n > 2:
		undo_redo.add_do_method(current_selection.curve, 'set_point_out', orig_n - 2, Vector2.ZERO)

	var redo_arcs : Array[ScalableArc] = []
	for a : ScalableArc in current_selection.arc_list.arcs:
		if a.start_point == idx or a.start_point == idx - 1:
			undo_redo.add_do_method(current_selection.arc_list, 'remove_arc_for_point', a.start_point)
			redo_arcs.append(a)

	undo_redo.add_do_method(current_selection.curve, 'remove_point', idx)
	undo_redo.add_do_method(current_selection.arc_list, 'handle_point_removed_at_index', idx)
	undo_redo.add_undo_method(current_selection, 'replace_curve_points', backup)
	undo_redo.add_undo_method(current_selection.arc_list, 'handle_point_added_at_index', idx)
	for a in redo_arcs:
		undo_redo.add_undo_reference(a)
		undo_redo.add_undo_method(current_selection.arc_list, 'add_arc', a)

	undo_redo.commit_action()


func _remove_cp_in_from_curve(current_selection : ScalableVectorShape2D, idx : int) -> void:
	if idx == 0:
		idx = current_selection.curve.point_count - 1
	undo_redo.create_action("Remove control point in %d from %s " % [idx, str(current_selection)])
	undo_redo.add_do_method(current_selection.curve, 'set_point_in', idx, Vector2.ZERO)
	undo_redo.add_undo_method(current_selection.curve, 'set_point_in', idx, current_selection.curve.get_point_in(idx))
	undo_redo.commit_action()


func _remove_cp_out_from_curve(current_selection : ScalableVectorShape2D, idx : int) -> void:
	if idx == current_selection.curve.point_count - 1:
		idx = 0
	undo_redo.create_action("Remove control point out %d from %s " % [idx, str(current_selection)])
	undo_redo.add_do_method(current_selection.curve, 'set_point_out', idx, Vector2.ZERO)
	undo_redo.add_undo_method(current_selection.curve, 'set_point_out', idx, current_selection.curve.get_point_out(idx))
	undo_redo.commit_action()


func _remove_rounded_corners_from_rect(svs : ScalableVectorShape2D):
	undo_redo.create_action("Remove rounded corners from %s " % str(svs))
	undo_redo.add_do_property(svs, 'rx', 0.0)
	undo_redo.add_do_property(svs, 'ry', 0.0)
	undo_redo.add_undo_property(svs, 'rx', svs.rx)
	undo_redo.add_undo_property(svs, 'ry', svs.ry)
	undo_redo.commit_action()


func _add_point_to_curve(svs : ScalableVectorShape2D, local_pos : Vector2,
		cp_in := Vector2.ZERO, cp_out := Vector2.ZERO, idx := -1) -> void:
	undo_redo.create_action("Add point at %s to %s " % [str(local_pos), str(svs)])

	undo_redo.add_do_method(svs.curve, 'add_point', local_pos, cp_in, cp_out, idx)
	if idx < 0:
		undo_redo.add_undo_method(svs.curve, 'remove_point', svs.curve.point_count)
	else:
		undo_redo.add_do_method(svs.arc_list, 'handle_point_added_at_index', idx)
		undo_redo.add_undo_method(svs.curve, 'remove_point', idx)
		undo_redo.add_undo_method(svs.arc_list, 'handle_point_removed_at_index', idx)
	undo_redo.commit_action()


func _create_arc(svs :  ScalableVectorShape2D, start_point_idx : int) -> void:
	undo_redo.create_action("Remove arc for segment %d on %s " % [start_point_idx, str(svs)])
	undo_redo.add_do_method(svs, 'add_arc', start_point_idx)
	undo_redo.add_undo_method(svs.arc_list, 'remove_arc_for_point', start_point_idx)
	undo_redo.commit_action()


func _remove_arc(svs : ScalableVectorShape2D, start_point_idx : int) -> void:
	var redo_arc := svs.arc_list.get_arc_for_point(start_point_idx)
	if redo_arc == null:
		return
	undo_redo.create_action("Remove arc for segment %d on %s " % [start_point_idx, str(svs)])
	undo_redo.add_do_method(svs.arc_list, 'remove_arc_for_point', start_point_idx)
	undo_redo.add_undo_method(svs.arc_list, 'add_arc', redo_arc)
	undo_redo.add_undo_reference(redo_arc)
	undo_redo.commit_action()


func _add_point_on_position(svs : ScalableVectorShape2D, pos : Vector2) -> void:
	if svs.shape_type != ScalableVectorShape2D.ShapeType.PATH:
		return
	_add_point_to_curve(svs, svs.to_local(pos))


func _start_cutout_shape(svs : ScalableVectorShape2D, pos : Vector2) -> void:
	var new_shape = ScalableVectorShape2D.new()
	new_shape.curve = Curve2D.new()
	new_shape.curve.add_point(Vector2.ZERO)
	new_shape.position = svs.to_local(EditorInterface.get_editor_viewport_2d().get_mouse_position())

	_create_shape(new_shape, EditorInterface.get_edited_scene_root(), "CutoutOf%s" % svs.name, svs)


func _add_point_on_curve_segment(svs : ScalableVectorShape2D) -> void:
	if svs.shape_type != ScalableVectorShape2D.ShapeType.PATH:
		return
	if not svs.has_meta(META_NAME_HOVER_CLOSEST_POINT):
		return
	var md_closest_point : ClosestPointOnCurveMeta = svs.get_meta(META_NAME_HOVER_CLOSEST_POINT)
	if svs.is_arc_start(md_closest_point.before_segment - 1):
		return
	if md_closest_point.before_segment >= svs.curve.point_count:
		_add_point_to_curve(svs, md_closest_point.local_point_position)
	else:
		_add_point_to_curve(svs, md_closest_point.local_point_position,
				Vector2.ZERO, Vector2.ZERO, md_closest_point.before_segment)


func _drag_curve_segment(svs : ScalableVectorShape2D, mouse_pos : Vector2) -> void:
	if svs.shape_type != ScalableVectorShape2D.ShapeType.PATH:
		return
	if not svs.has_meta(META_NAME_HOVER_CLOSEST_POINT):
		return
	var md_closest_point : ClosestPointOnCurveMeta = svs.get_meta(META_NAME_HOVER_CLOSEST_POINT)
	if svs.is_arc_start(md_closest_point.before_segment - 1) or md_closest_point.before_segment >= svs.curve.point_count or md_closest_point.before_segment < 1:
		return

	# Compute control points based on mouse position to align middle of segment curve to it
	# using the quadratic Bézier control point
	var idx : int = md_closest_point.before_segment
	var segment_start_point := svs.curve.get_point_position(idx - 1)
	var segment_end_point := svs.curve.get_point_position(idx)
	var halfway_point := (segment_start_point + segment_end_point) / 2
	var dir := halfway_point.direction_to(svs.to_local(mouse_pos))
	var distance := halfway_point.distance_to(svs.to_local(mouse_pos))
	var quadratic_bezier_control_point := halfway_point + distance * 2 * dir
	var new_point_out := (quadratic_bezier_control_point - segment_start_point) * (2.0 / 3.0)
	var new_point_in := (quadratic_bezier_control_point - segment_end_point) * (2.0 / 3.0)

	if not in_undo_redo_transaction:
		_start_undo_redo_transaction("Change curve segment %d->%d for %s" % [idx - 1, idx, str(svs)])
		undo_redo_transaction[UndoRedoEntry.UNDOS].append([svs.curve, 'set_point_in', idx, svs.curve.get_point_in(idx)])
		undo_redo_transaction[UndoRedoEntry.UNDOS].append([svs.curve, 'set_point_out', idx - 1, svs.curve.get_point_out(idx - 1)])
	undo_redo_transaction[UndoRedoEntry.DOS] = [[svs.curve, 'set_point_out', idx - 1, new_point_out]]
	undo_redo_transaction[UndoRedoEntry.DOS].append([svs.curve, 'set_point_in', idx, new_point_in])
	svs.curve.set_point_out(idx - 1, new_point_out)
	svs.curve.set_point_in(idx, new_point_in)
	md_closest_point["point_position"] = mouse_pos
	svs.set_meta(META_NAME_HOVER_CLOSEST_POINT, md_closest_point)
	update_overlays()


func _toggle_loop_if_applies(svs : ScalableVectorShape2D, idx : int) -> void:
	if svs.shape_type != ScalableVectorShape2D.ShapeType.PATH:
		return
	if svs.curve.point_count < 3:
		return
	if idx == 0 or idx == svs.curve.point_count - 1:
		if svs.is_curve_closed():
			_remove_point_from_curve(svs, svs.curve.point_count - 1)
		else:
			_add_point_to_curve(svs, svs.curve.get_point_position(0))


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if (in_undo_redo_transaction and event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_commit_undo_redo_transaction()
	if (in_undo_redo_transaction and event is InputEventKey
			and event.keycode == KEY_SHIFT and
			not Input.is_key_pressed(KEY_SHIFT)):
		_commit_undo_redo_transaction()
	if not _is_editing_enabled():
		return false
	if not _is_change_pivot_button_active() and not _get_select_mode_button().button_pressed:
		return false
	if not is_instance_valid(EditorInterface.get_edited_scene_root()):
		return false
	var current_selection := EditorInterface.get_selection().get_selected_nodes().pop_back()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := EditorInterface.get_editor_viewport_2d().get_mouse_position()
		if _is_change_pivot_button_active():
			if _is_svs_valid(current_selection):
				_set_shape_origin(current_selection, mouse_pos)
		else:
			if _is_svs_valid(current_selection) and _handle_has_hover(current_selection):
				if event.double_click and current_selection.has_meta(META_NAME_HOVER_POINT_IDX):
					_toggle_loop_if_applies(current_selection, current_selection.get_meta(META_NAME_HOVER_POINT_IDX))
				elif (_is_svs_valid(current_selection) and Input.is_key_pressed(KEY_ALT)
						and current_selection.shape_type == ScalableVectorShape2D.ShapeType.PATH
						and _curve_control_has_hover(current_selection)):
					set_global_position_popup_panel.popup_with_value(
							_get_hovered_handle_metadata(current_selection),
							_is_snapped_to_pixel(),
							_get_snap_resolution()
					)
				return true
			elif _is_svs_valid(current_selection) and Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_SHIFT):
				if (not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and
							current_selection.has_fine_point(mouse_pos)):
					_start_cutout_shape(current_selection, mouse_pos)
				return true
			elif _is_svs_valid(current_selection) and Input.is_key_pressed(KEY_CTRL):
				if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
					_add_point_on_position(current_selection, mouse_pos)
				return true
			elif _is_svs_valid(current_selection) and current_selection.has_meta(META_NAME_HOVER_CLOSEST_POINT):
				var cp_md : ClosestPointOnCurveMeta = current_selection.get_meta(META_NAME_HOVER_CLOSEST_POINT)
				if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and current_selection.is_arc_start(cp_md.before_segment - 1):
					arc_settings_popup_panel.popup_with_value(current_selection.arc_list.get_arc_for_point(cp_md.before_segment - 1))
				elif event.double_click:
					_add_point_on_curve_segment(current_selection)
				return true
			elif _is_svs_valid(current_selection) and current_selection.has_meta(META_NAME_HOVER_CLOSEST_POINT_ON_GRADIENT_LINE):
				if event.double_click:
					_add_color_stop(current_selection, mouse_pos)
				return true
			else:
				var results := _find_scalable_vector_shape_2d_nodes_at(mouse_pos)
				var refined_result := results.rfind_custom(func(x): return x.has_fine_point(mouse_pos))
				if refined_result > -1 and results[refined_result]:
					if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
						selection_candidate = results[refined_result]
						return true
					else:
						if selection_candidate == results[refined_result]:
							EditorInterface.edit_node(results[refined_result])
							return true
				var result = results.pop_back()
				if is_instance_valid(result):
					if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
						selection_candidate = result
						return true
					else:
						if selection_candidate == result:
							EditorInterface.edit_node(result)
							return true
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if _is_svs_valid(current_selection) and _handle_has_hover(current_selection):
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				if current_selection.has_meta(META_NAME_HOVER_POINT_IDX) and current_selection.shape_type == ScalableVectorShape2D.ShapeType.PATH:
					_remove_point_from_curve(current_selection, current_selection.get_meta(META_NAME_HOVER_POINT_IDX))
				elif current_selection.has_meta(META_NAME_HOVER_CP_IN_IDX):
					if current_selection.shape_type == ScalableVectorShape2D.ShapeType.RECT:
						_remove_rounded_corners_from_rect(current_selection)
					else:
						_remove_cp_in_from_curve(current_selection, current_selection.get_meta(META_NAME_HOVER_CP_IN_IDX))
				elif current_selection.has_meta(META_NAME_HOVER_CP_OUT_IDX):
					if current_selection.shape_type == ScalableVectorShape2D.ShapeType.RECT:
						_remove_rounded_corners_from_rect(current_selection)
					else:
						_remove_cp_out_from_curve(current_selection, current_selection.get_meta(META_NAME_HOVER_CP_OUT_IDX))
				elif current_selection.has_meta(META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX):
					_remove_color_stop(current_selection, current_selection.get_meta(META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX))
			return true
		if _is_svs_valid(current_selection) and current_selection.has_meta(META_NAME_HOVER_CLOSEST_POINT) and not _handle_has_hover(current_selection):
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				var cp_md = current_selection.get_meta(META_NAME_HOVER_CLOSEST_POINT)
				if current_selection.is_arc_start(cp_md.before_segment - 1):
					_remove_arc(current_selection, cp_md.before_segment - 1)
				else:
					_create_arc(current_selection, cp_md.before_segment - 1)

			return true

	if (event is InputEventMouseButton and Input.is_key_pressed(KEY_SHIFT) and
			event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		if _is_svs_valid(current_selection):
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_resize_shape(current_selection, 0.99)
			else:
				_resize_shape(current_selection, 1.01)
			return true

	if event is InputEventMouseMotion:
		var mouse_pos := EditorInterface.get_editor_viewport_2d().get_mouse_position()
		for result in _find_scalable_vector_shape_2d_nodes():
			result.remove_meta(META_NAME_SELECT_HINT)

		if _is_svs_valid(current_selection) and not _handle_has_hover(current_selection) and current_selection.has_meta(META_NAME_HOVER_CLOSEST_POINT):
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_drag_curve_segment(current_selection, mouse_pos)
				return true

		if _is_svs_valid(current_selection):
			current_selection.remove_meta(META_NAME_HOVER_CLOSEST_POINT)

		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _is_svs_valid(current_selection):
			if _handle_has_hover(current_selection):
				if current_selection.has_meta(META_NAME_HOVER_POINT_IDX):
					var pt_idx : int = current_selection.get_meta(META_NAME_HOVER_POINT_IDX)
					if current_selection.shape_type != ScalableVectorShape2D.ShapeType.PATH:
						_update_rect_dimensions(current_selection, mouse_pos)
					elif Input.is_key_pressed(KEY_SHIFT):
						if pt_idx == 0:
							_update_curve_cp_out_position(current_selection, mouse_pos, pt_idx)
						else:
							_update_curve_cp_in_position(current_selection, mouse_pos, pt_idx)
					else:
						_update_curve_point_position(current_selection, mouse_pos, pt_idx)
				elif current_selection.has_meta(META_NAME_HOVER_CP_IN_IDX):
					if current_selection.shape_type == ScalableVectorShape2D.ShapeType.RECT:
						_update_rect_corner_radius(current_selection, mouse_pos, "rx", !Input.is_key_pressed(KEY_SHIFT))
					else:
						_update_curve_cp_in_position(current_selection, mouse_pos, current_selection.get_meta(META_NAME_HOVER_CP_IN_IDX))
				elif current_selection.has_meta(META_NAME_HOVER_CP_OUT_IDX):
					if current_selection.shape_type == ScalableVectorShape2D.ShapeType.RECT:
						_update_rect_corner_radius(current_selection, mouse_pos, "ry", !Input.is_key_pressed(KEY_SHIFT))
					else:
						_update_curve_cp_out_position(current_selection, mouse_pos, current_selection.get_meta(META_NAME_HOVER_CP_OUT_IDX))
				elif current_selection.has_meta(META_NAME_HOVER_GRADIENT_FROM):
					_update_gradient_from_position(current_selection, mouse_pos)
				elif current_selection.has_meta(META_NAME_HOVER_GRADIENT_TO):
					_update_gradient_to_position(current_selection, mouse_pos)
				elif current_selection.has_meta(META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX):
					_update_gradient_stop_color_pos(current_selection, mouse_pos,
							current_selection.get_meta(META_NAME_HOVER_GRADIENT_COLOR_STOP_IDX))
				update_overlays()
				return true
		else:
			for result : ScalableVectorShape2D in _find_scalable_vector_shape_2d_nodes_at(mouse_pos):
				result.set_meta(META_NAME_SELECT_HINT, true)
			if _is_svs_valid(current_selection):
				_set_handle_hover(mouse_pos, current_selection)
		update_overlays()
	return false


static func _is_editing_enabled() -> bool:
	if ProjectSettings.has_setting(SETTING_NAME_EDITING_ENABLED):
		return ProjectSettings.get_setting(SETTING_NAME_EDITING_ENABLED)
	return true


static func _are_hints_enabled() -> bool:
	if ProjectSettings.has_setting(SETTING_NAME_HINTS_ENABLED):
		return ProjectSettings.get_setting(SETTING_NAME_HINTS_ENABLED)
	return true


static func _am_showing_point_numbers() -> bool:
	if ProjectSettings.has_setting(SETTING_NAME_SHOW_POINT_NUMBERS):
		return ProjectSettings.get_setting(SETTING_NAME_SHOW_POINT_NUMBERS)
	return true


static func _get_default_stroke_width() -> float:
	if ProjectSettings.has_setting(SETTING_NAME_STROKE_WIDTH):
		return ProjectSettings.get_setting(SETTING_NAME_STROKE_WIDTH)
	return 10.0


static func _get_default_stroke_color() -> Color:
	if ProjectSettings.has_setting(SETTING_NAME_STROKE_COLOR):
		return ProjectSettings.get_setting(SETTING_NAME_STROKE_COLOR)
	return Color.WHITE


static func _get_default_begin_cap() -> Line2D.LineCapMode:
	if ProjectSettings.has_setting(SETTING_NAME_DEFAULT_LINE_BEGIN_CAP):
		return ProjectSettings.get_setting(SETTING_NAME_DEFAULT_LINE_BEGIN_CAP)
	return Line2D.LineCapMode.LINE_CAP_NONE


static func _get_default_end_cap() -> Line2D.LineCapMode:
	if ProjectSettings.has_setting(SETTING_NAME_DEFAULT_LINE_END_CAP):
		return ProjectSettings.get_setting(SETTING_NAME_DEFAULT_LINE_END_CAP)
	return Line2D.LineCapMode.LINE_CAP_NONE


static func _get_default_joint_mode() -> Line2D.LineJointMode:
	if ProjectSettings.has_setting(SETTING_NAME_DEFAULT_LINE_JOINT_MODE):
		return ProjectSettings.get_setting(SETTING_NAME_DEFAULT_LINE_JOINT_MODE)
	return Line2D.LineJointMode.LINE_JOINT_SHARP


static func _get_default_fill_color() -> Color:
	if ProjectSettings.has_setting(SETTING_NAME_FILL_COLOR):
		return ProjectSettings.get_setting(SETTING_NAME_FILL_COLOR)
	return Color.WHITE


static func _is_add_stroke_enabled() -> bool:
	if ProjectSettings.has_setting(SETTING_NAME_ADD_STROKE_ENABLED):
		return ProjectSettings.get_setting(SETTING_NAME_ADD_STROKE_ENABLED)
	return true


static func _is_add_fill_enabled() -> bool:
	if ProjectSettings.has_setting(SETTING_NAME_ADD_FILL_ENABLED):
		return ProjectSettings.get_setting(SETTING_NAME_ADD_FILL_ENABLED)
	return true


static func _add_collision_object_type() -> ScalableVectorShape2D.CollisionObjectType:
	if ProjectSettings.has_setting(SETTING_NAME_ADD_COLLISION_TYPE):
		return ProjectSettings.get_setting(SETTING_NAME_ADD_COLLISION_TYPE)
	return ScalableVectorShape2D.CollisionObjectType.NONE



static func _get_default_paint_order() -> PaintOrder:
	if ProjectSettings.has_setting(SETTING_NAME_PAINT_ORDER):
		return ProjectSettings.get_setting(SETTING_NAME_PAINT_ORDER)
	return PaintOrder.FILL_STROKE_MARKERS


static func _is_snapped_to_pixel() -> bool:
	if ProjectSettings.has_setting(SETTING_NAME_SNAP_TO_PIXEL):
		return ProjectSettings.get_setting(SETTING_NAME_SNAP_TO_PIXEL)
	return false


static func _get_snap_resolution() -> float:
	if ProjectSettings.has_setting(SETTING_NAME_SNAP_RESOLUTION):
		return ProjectSettings.get_setting(SETTING_NAME_SNAP_RESOLUTION)
	return 1.0


func _exit_tree():
	remove_inspector_plugin(plugin)
	remove_custom_type("DrawablePath2D")
	remove_custom_type("ScalableVectorShape2D")
	remove_control_from_bottom_panel(scalable_vector_shapes_2d_dock)
	scalable_vector_shapes_2d_dock.free()
	set_global_position_popup_panel.free()
