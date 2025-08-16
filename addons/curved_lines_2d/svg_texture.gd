@tool
extends ImageTexture

class_name SVGTexture

func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	print("_draw(", to_canvas_item," ", pos," ", modulate," ", transpose, ")")
