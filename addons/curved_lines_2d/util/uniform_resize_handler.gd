class_name UniformResizeHandler extends Object

static var _drag_start := Vector2.INF
static var _stashed_curve : Curve2D = null
static var _svs_under_edit : ScalableVectorShape2D = null

static var temp_pivot_is_hovered := false
static var temp_pivot := Vector2.INF
static var temp_pivot_hint := Vector2.INF

static func clear_settings() -> void:
	commit_changes(_svs_under_edit)
	_drag_start = Vector2.INF
	temp_pivot = Vector2.INF
	_stashed_curve = null
	_svs_under_edit = null
	temp_pivot_hint = Vector2.INF


static func commit_changes(svs : ScalableVectorShape2D) -> void:
	if not is_instance_valid(svs):
		return
	if _drag_start != Vector2.INF:
		_drag_start = Vector2.INF
		if _stashed_curve != null:
			var undo_redo := EditorInterface.get_editor_undo_redo()
			undo_redo.create_action("Scale points")
			undo_redo.add_do_property(svs, "curve", svs.curve.duplicate(true))
			undo_redo.add_undo_property(svs, "curve", _stashed_curve)
			undo_redo.commit_action(false)
			_stashed_curve = null
			_svs_under_edit = null


static func handle_input(event : InputEvent, svs : ScalableVectorShape2D, mouse_pos : Vector2,
			is_snapped_to_pixel : bool, snap_resolution : Vector2, vp_transform : Callable) -> bool:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			if (event as InputEventMouseButton).alt_pressed:
				temp_pivot = mouse_pos.snapped(snap_resolution) if is_snapped_to_pixel else mouse_pos
			else:
				_drag_start = mouse_pos
				temp_pivot = svs.to_global(svs.get_center(MultiSelectHandler.selection(svs))) if temp_pivot == Vector2.INF else temp_pivot
				_stashed_curve = svs.curve.duplicate(true)
				_svs_under_edit = svs
		else:
			commit_changes(svs)
		return true

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _drag_start == Vector2.INF:
				_drag_start = mouse_pos
			if temp_pivot_is_hovered:
				temp_pivot = mouse_pos.snapped(snap_resolution) if is_snapped_to_pixel else mouse_pos
				return true
			if _stashed_curve == null:
				_stashed_curve = svs.curve.duplicate(true)
				_svs_under_edit = svs
			var use_temp_pivot := (not Input.is_key_pressed(KEY_SHIFT)) or svs.shape_type != ScalableVectorShape2D.ShapeType.PATH
			var origin = (
					temp_pivot
						if use_temp_pivot and not temp_pivot == Vector2.INF else
					svs.global_position
			)
			var drag_delta := mouse_pos - _drag_start
			if is_snapped_to_pixel:
				drag_delta = drag_delta.snapped(snap_resolution)
			if drag_delta.abs() > Vector2.ZERO:
				svs.scale_points_by(_drag_start, mouse_pos,
					svs.to_local(origin) if use_temp_pivot else Vector2.ZERO,
					MultiSelectHandler.selection(svs))
				_drag_start = mouse_pos
		elif (event as InputEventMouseMotion).alt_pressed:
			temp_pivot_hint = mouse_pos.snapped(snap_resolution) if is_snapped_to_pixel else mouse_pos
		else:
			var piv := svs.to_global(svs.get_center(MultiSelectHandler.selection(svs)))
			if temp_pivot != Vector2.INF:
				piv = temp_pivot
			temp_pivot_is_hovered = vp_transform.call(mouse_pos).distance_to(vp_transform.call(piv)) < 10.0
			temp_pivot_hint = Vector2.INF
		return true
	return false


static func draw(viewport_control : Control, svs : ScalableVectorShape2D,
		draw_hint : Callable, lmb_down : bool, _ctrl_pressed : bool,
		vp_transform : Callable, svp_transform : Transform2D) -> void:
	if temp_pivot_is_hovered:
		draw_hint.call(viewport_control, "- Drag to move temporary pivot")
		return
	if lmb_down:
		var hint_text := "- Drag to resize points (left mouse button held)"
		if svs.shape_type == ScalableVectorShape2D.ShapeType.PATH:
			if Input.is_key_pressed(KEY_SHIFT):
				hint_text += "\n- Scaling out from origin (Shift held)"
			else:
				hint_text += "\n- Hold Shift to scale out from origin in stead of pivot"

		draw_hint.call(viewport_control, hint_text)
	else:
		var hint_text := "- Drag Left Mouse Button to resize points"
		if Input.is_key_pressed(KEY_ALT):
			hint_text += "\n- Left Click to change temporary pivot position (Alt held)"
		else:
			hint_text += "\n- Alt + Left Click to change temporary pivot position"
		draw_hint.call(viewport_control, hint_text +
				"\n- Press Q to return to normal editing")

	if lmb_down:
		var origin = temp_pivot if svs.shape_type == ScalableVectorShape2D.ShapeType.PATH else svs.global_position
		if (origin == Vector2.INF or Input.is_key_pressed(KEY_SHIFT) or
				svs.shape_type != ScalableVectorShape2D.ShapeType.PATH
		):
			origin = svs.global_position if ScalableVectorShape2D.ShapeType.PATH else svs.to_global(svs.offset)
		var target := EditorInterface.get_editor_viewport_2d().get_mouse_position()
		viewport_control.draw_line(vp_transform.call(origin * svp_transform), vp_transform.call(target),
				svs.shape_hint_color, 1, true)
