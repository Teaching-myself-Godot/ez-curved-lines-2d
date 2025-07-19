@tool
extends Object

# Centers polygon points around its natural center
# source: https://github.com/mrkdji/knife-tool/blob/64f5838fa79192bc0c221cf36d53f8403ee0ffc5/knife_tool.gd#L464
static func origin_to_geometry(polygon_data : PackedVector2Array) -> Vector2:
	var centroid := Vector2.ZERO;
	for i in polygon_data.size():
		centroid += polygon_data[i]

	centroid /= polygon_data.size()

	for i in polygon_data.size():
		polygon_data[i] -= centroid

	return centroid


