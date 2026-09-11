@tool
extends Control

signal mode_changed(new_mode : CurvedLines2D.SVSEditMode)


func _ready() -> void:
	show_details_for_current_mode()
	%CircleButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.CREATE_ELLIPSE))
	%RectangleButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.CREATE_RECT))
	%EditButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.NONE))
	%TranslateButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.TRANSLATE))
	%ResizeButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.SCALE))
	%RotateButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.ROTATE))
	%BrushButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.BRUSH))
	%PencilButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.PENCIL))
	%KnifeButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.KNIFE))
	%BonePaintButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.PAINT_BONE))
	%MergeButton.toggled.connect(_on_mode_toggled.bind(CurvedLines2D.SVSEditMode.MERGE))


func _on_mode_toggled(toggled_on : bool, mode : CurvedLines2D.SVSEditMode) -> void:
	if toggled_on:
		mode_changed.emit(mode)


func set_edit_mode_toggle_button(mode : CurvedLines2D.SVSEditMode) -> void:
	match mode:
		CurvedLines2D.SVSEditMode.CREATE_ELLIPSE:
			if not %CircleButton.button_pressed:
				%CircleButton.button_pressed = true
		CurvedLines2D.SVSEditMode.CREATE_RECT:
			if not %RectangleButton.button_pressed:
				%RectangleButton.button_pressed = true
		CurvedLines2D.SVSEditMode.NONE:
			if not %EditButton.button_pressed:
				%EditButton.button_pressed = true
		CurvedLines2D.SVSEditMode.TRANSLATE:
			if not %TranslateButton.button_pressed:
				%TranslateButton.button_pressed = true
		CurvedLines2D.SVSEditMode.SCALE:
			if not %ResizeButton.button_pressed:
				%ResizeButton.button_pressed = true
		CurvedLines2D.SVSEditMode.ROTATE:
			if not %RotateButton.button_pressed:
				%RotateButton.button_pressed = true
		CurvedLines2D.SVSEditMode.BRUSH:
			if not %BrushButton.button_pressed:
				%BrushButton.button_pressed = true
		CurvedLines2D.SVSEditMode.PENCIL:
			if not %PencilButton.button_pressed:
				%PencilButton.button_pressed = true
		CurvedLines2D.SVSEditMode.KNIFE:
			if not %KnifeButton.button_pressed:
				%KnifeButton.button_pressed = true
		CurvedLines2D.SVSEditMode.PAINT_BONE:
			if not %BonePaintButton.button_pressed:
				%BonePaintButton.button_pressed = true
		CurvedLines2D.SVSEditMode.MERGE:
			if not %MergeButton.button_pressed:
				%MergeButton.button_pressed = true
		_:
			if not %EditButton.button_pressed:
				%EditButton.button_pressed = true
	show_details_for_current_mode()


func show_details_for_current_mode() -> void:
	push_warning("TODO: show currect details for: ", (%EditButton.button_group as ButtonGroup).get_pressed_button())


func enable_svs_editors() -> void:
	%RotateButton.disabled = false
	%TranslateButton.disabled = false
	%ResizeButton.disabled = false
	%FlipHorizontalButton.disabled = false
	%FlipVerticalButton.disabled = false
	%BonePaintButton.disabled = false
	%EditButton.disabled = false
	%KnifeButton.disabled = false
	%EditButton.button_pressed = true
	%BrushButton.disabled = false
	%MergeButton.disabled = false
	%PencilButton.disabled = false


func disable_svs_editors(disable_all := false) -> void:
	%RotateButton.disabled = true
	%TranslateButton.disabled = true
	%ResizeButton.disabled = true
	%FlipHorizontalButton.disabled = true
	%FlipVerticalButton.disabled = true
	%BonePaintButton.disabled = true
	%EditButton.disabled = true
	%KnifeButton.disabled = true
	%CircleButton.button_pressed = true
	%BrushButton.disabled = disable_all
	%MergeButton.disabled = disable_all
	%PencilButton.disabled = disable_all


func disable_all_editors() -> void:
	disable_svs_editors(true)
