@tool
extends TabContainer

signal shape_created(curve : Curve2D, scene_root : Node2D, node_name : String)
signal set_shape_preview(curve : Curve2D)
signal brush_changed()

const TABS_NAME := [
	"Project Settings",
	"Create",
	"Import SVG File",
	"Advanced Editing",
	"Help"
]

var warning_dialog : AcceptDialog
var import_tab : Control
var create_tab : Control

func _enter_tree() -> void:
	for i in min(TABS_NAME.size(), get_child_count()):
		set_tab_title(i, TABS_NAME[i])

	import_tab = %SVGImportTab
	create_tab = %CreateTab
	warning_dialog = AcceptDialog.new()
	EditorInterface.get_base_control().add_child(warning_dialog)
	import_tab.warning_dialog = warning_dialog
	create_tab.warning_dialog = warning_dialog
	if not create_tab.shape_created.is_connected(shape_created.emit):
		create_tab.shape_created.connect(shape_created.emit)
	if not create_tab.set_shape_preview.is_connected(set_shape_preview.emit):
		create_tab.set_shape_preview.connect(set_shape_preview.emit)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not typeof(data) == TYPE_DICTIONARY and "type" in data and data["type"] == "files":
		return false
	for file : String in data["files"]:
		if file.ends_with(".svg"):
			import_tab.show()
			return true
	return false


func set_selected_animation_player(animation_player : AnimationPlayer) -> void:
	%AdvancedTab.set_animation_player(animation_player)


func _on_draw_settings_tab_brush_changed() -> void:
	brush_changed.emit()


func sync_draw_settings() -> void:
	create_tab.sync_draw_settings()


func _on_mouse_entered() -> void:
	set_shape_preview.emit(null)
