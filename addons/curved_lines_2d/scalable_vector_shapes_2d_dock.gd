@tool
extends TabContainer

signal shape_created(curve : Curve2D, scene_root : Node2D, node_name : String)
signal set_shape_preview(curve : Curve2D)

const TABS_NAME := [
	"Project Settings",
	"Create Shapes",
	"Import SVG File",
	"Advanced Editing",
	"Video Explainers"
]

var warning_dialog : AcceptDialog
var edit_tab : Control
var import_tab : Control

func _enter_tree() -> void:
	for i in min(TABS_NAME.size(), get_child_count()):
		set_tab_title(i, TABS_NAME[i])

	edit_tab = %SVSEditTab
	import_tab = %SVGImportTab
	warning_dialog = AcceptDialog.new()
	EditorInterface.get_base_control().add_child(warning_dialog)
	edit_tab.warning_dialog = warning_dialog
	import_tab.warning_dialog = warning_dialog

	if not edit_tab.shape_created.is_connected(shape_created.emit):
		edit_tab.shape_created.connect(shape_created.emit)
	if not edit_tab.set_shape_preview.is_connected(set_shape_preview.emit):
		edit_tab.set_shape_preview.connect(set_shape_preview.emit)


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
