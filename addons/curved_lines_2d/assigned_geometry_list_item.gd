@tool
extends HBoxContainer

var svs : ScalableVectorShape2D: set = _on_svs_assigned

func _on_svs_assigned(s : ScalableVectorShape2D) -> void:
	svs = s
	if not is_instance_valid(svs):
		return
	if svs.use_interect_when_clipping:
		%ClipOffShapesButton.button_pressed = true
	elif svs.use_union_in_stead_of_clipping:
		%MergeShapesButton.button_pressed = true
	else:
		%CutOutShapesButton.button_pressed = true
	%Button.text = s.name


func _on_merge_shapes_button_toggled(toggled_on: bool) -> void:
	if svs and svs is ScalableVectorShape2D:
		svs.use_interect_when_clipping = false
		svs.use_union_in_stead_of_clipping = true

func _on_cut_out_shapes_button_toggled(toggled_on: bool) -> void:
	if svs and svs is ScalableVectorShape2D:
		svs.use_interect_when_clipping = false
		svs.use_union_in_stead_of_clipping = false


func _on_clip_off_shapes_button_toggled(toggled_on: bool) -> void:
	if svs and svs is ScalableVectorShape2D:
		svs.use_interect_when_clipping = true
		svs.use_union_in_stead_of_clipping = false


func _on_button_pressed() -> void:
	if is_instance_valid(svs):
		EditorInterface.edit_node(svs)
