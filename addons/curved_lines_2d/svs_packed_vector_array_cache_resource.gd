class_name SVSPackedVectorArrayCacheResource extends Resource

@export var cache : Dictionary[int, PackedVector2Array]

func _init(c : Dictionary[int, PackedVector2Array] = {}) -> void:
	cache = c
