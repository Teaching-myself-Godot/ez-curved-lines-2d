@tool
class_name ClipPathList
extends Resource

@export var clip_paths : Array[ScalableVectorPath2D]:
	set(_clip_paths):
		clip_paths = _clip_paths
		for i in clip_paths.size():
			if clip_paths[i] == null:
				clip_paths[i] = ScalableVectorPath2D.new()
		emit_changed()


func _init(c : Array[ScalableVectorPath2D] = []) -> void:
	clip_paths = c
	if not changed.is_connected(_on_changed):
		changed.connect(_on_changed)
	_on_changed()


func _get(property: StringName) -> Variant:
	var components := property.split("/", true, 2)
	if components.size() >= 2:
		var clip_path_idx := components[0].trim_prefix("clip_path_").to_int()
		if clip_path_idx >= clip_paths.size():
			return null
		var clip_path := clip_paths[clip_path_idx]
		if components[1] in clip_path:
			return clip_path[components[1]]
		return null
	return null


func _set(property: StringName, value: Variant) -> bool:
	var components := property.split("/", true, 2)
	if components.size() >= 2:
		var clip_path_idx := components[0].trim_prefix("clip_path_").to_int()
		if clip_path_idx >= clip_paths.size():
			return false
		var clip_path := clip_paths[clip_path_idx]
		if components[1] in clip_path:
			clip_path[components[1]] = value
			return true
	return false


func _on_changed():
	for c : ScalableVectorPath2D in clip_paths:
		if c and not c.changed.is_connected(_item_changed):
			c.changed.connect(_item_changed)


func _item_changed():
	emit_changed()


func remove(idx : int) -> void:
	clip_paths.remove_at(idx)
	emit_changed()


func add(c : ScalableVectorPath2D) -> void:
	clip_paths.append(c)
	_on_changed()
	emit_changed()
