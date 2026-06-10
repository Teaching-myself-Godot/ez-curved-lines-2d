@tool
extends Bone2D

class_name SVSBone2D

signal transform_changed(ref : SVSBone2D)

func _enter_tree() -> void:
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		transform_changed.emit(self)
