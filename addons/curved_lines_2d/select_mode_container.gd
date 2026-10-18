@tool
extends ScrollContainer

signal create_empty_shape()


func _ready() -> void:
	if not EditorInterface.get_selection().selection_changed.is_connected(_on_selection_changed):
		EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)


func _on_create_empty_shape_button_pressed() -> void:
	create_empty_shape.emit()


func sync_svs_settings(svs : ScalableVectorShape2D) -> void:
	%CreateEmptyShapeContainer.hide()

	print("TODO: sync: ", svs)


func _on_selection_changed() -> void:
	var sel := EditorInterface.get_selection().get_selected_nodes()
	if sel.filter(func(n): return n is ScalableVectorShape2D).is_empty():
		%CreateEmptyShapeContainer.show()

