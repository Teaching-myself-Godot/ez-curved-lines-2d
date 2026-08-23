@tool
extends Control

var error_label_settings : LabelSettings = null
var warning_label_settings : LabelSettings = null
var info_label_settings : LabelSettings = null
var debug_label_settings : LabelSettings = null

## Settings
var collision_object_type := ScalableVectorShape2D.CollisionObjectType.NONE
var import_as_svs := true
var lock_shapes := true
var antialiased_shapes := false
var import_stroke_as_line_2d := true
var import_file_dialog : EditorFileDialog = null
var warning_dialog : AcceptDialog = null
var undo_redo : EditorUndoRedoManager = null
var LinkButtonScene : PackedScene = null

func _enter_tree() -> void:
	error_label_settings = preload("res://addons/curved_lines_2d/error_label_settings.tres")
	warning_label_settings = preload("res://addons/curved_lines_2d/warn_label_settings.tres")
	info_label_settings = preload("res://addons/curved_lines_2d/info_label_settings.tres")
	debug_label_settings = preload("res://addons/curved_lines_2d/debug_label_settings.tres")
	LinkButtonScene = preload("res://addons/curved_lines_2d/link_button_with_copy_hint.tscn")
	%LogScrollContainer.get_v_scroll_bar().connect("changed", func(): %LogScrollContainer.scroll_vertical = %LogScrollContainer.get_v_scroll_bar().max_value )
	import_file_dialog = EditorFileDialog.new()
	import_file_dialog.add_filter("*.svg", "SVG image")
	import_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	import_file_dialog.file_selected.connect(_load_svg)
	EditorInterface.get_base_control().add_child(import_file_dialog)
	undo_redo = EditorInterface.get_editor_undo_redo()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not typeof(data) == TYPE_DICTIONARY and "type" in data and data["type"] == "files":
		return false
	for file : String in data["files"]:
		if file.ends_with(".svg"):
			return true
	return false


func log_message(msg : String, log_level := SVGImporter.LogLevel.INFO) -> void:
	var lbl := Label.new()
	match log_level:
		SVGImporter.LogLevel.ERROR:
			warning_dialog.dialog_text = msg
			warning_dialog.popup_centered()
			lbl.label_settings = error_label_settings
		SVGImporter.LogLevel.WARN:
			lbl.label_settings = warning_label_settings
		SVGImporter.LogLevel.DEBUG:
			lbl.label_settings = debug_label_settings
		SVGImporter.LogLevel.INFO,_:
			lbl.label_settings = info_label_settings
	lbl.text = msg

	%ImportLogContainer.add_child(lbl)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		_load_svg(data["files"][0])


func _load_svg(svg_file_path : String) -> void:
		var svg_importer := SVGImporter.new(
			import_as_svs, lock_shapes, antialiased_shapes, import_stroke_as_line_2d,
			collision_object_type, log_message
		)
		for child in %ImportLogContainer.get_children():
			child.queue_free()
		var svg_root := await svg_importer.load_svg(svg_file_path)
		log_message("Import finished.\n\nThe SVG importer is still incrementally improving (slowly).")
		var link_button = LinkButtonScene.instantiate()
		link_button.text = "Click here to report issues or improvement requests on github"
		link_button.uri = "https://github.com/Teaching-myself-Godot/ez-curved-lines-2d/issues"
		%ImportLogContainer.add_child(link_button)

		var selection_target = (
				svg_root.find_children("*", "ScalableVectorShape2D")
					.filter(func(n : CanvasItem): return n.is_visible_in_tree()).pop_front()
		)
		if not is_instance_valid(selection_target):
			selection_target = svg_root
		EditorInterface.call_deferred('edit_node', selection_target)
		await get_tree().create_timer(0.0167).timeout
		EditorInterface.get_editor_viewport_2d().get_parent().grab_focus()
		var key_ev := InputEventKey.new()
		key_ev.keycode = KEY_F
		key_ev.pressed = true
		Input.parse_input_event(key_ev)


func _on_collision_object_type_option_button_type_selected(obj_type: ScalableVectorShape2D.CollisionObjectType) -> void:
	collision_object_type = obj_type


func _on_keep_drawable_path_2d_node_check_box_toggled(toggled_on: bool) -> void:
	import_as_svs = toggled_on
	%LockShapesCheckBox.visible = toggled_on


func _on_lock_shapes_check_box_toggled(toggled_on: bool) -> void:
	lock_shapes = toggled_on


func _on_antialiased_check_box_toggled(toggled_on: bool) -> void:
	antialiased_shapes = toggled_on


func _on_open_file_dialog_button_pressed() -> void:
	import_file_dialog.popup_file_dialog()


func _on_use_line_2d_check_box_toggled(toggled_on: bool) -> void:
	import_stroke_as_line_2d = toggled_on
