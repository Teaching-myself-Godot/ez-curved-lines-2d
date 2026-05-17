@tool
class_name BasicFit
extends Object

const MAX_ANGLE_INBOUND_TO_OUTBOUND := deg_to_rad(30.0)
const MAX_CUMULATIVE_ANGLE_PER_SEGMENT := deg_to_rad(90.0)
const MIN_DISTANCE_BETWEEN_SEGMENT_STARTS := 50.0


static func prepare_polyline_segments(pts : PackedVector2Array) -> Array[int]:
	if pts.size() < 4:
		return [0]

	var splits : Array[int] = [0]
	# any point p of which the angle between the inbound and outbound line p_a exceeds 30.0° will
	# become the start of a new segment
	for i in range(1, pts.size()):
		var prev_p := pts[i - 1]
		var p := pts[i]
		var next_p := pts[i + 1] if i < pts.size() - 1 else pts[0]
		if absf(prev_p.direction_to(p).angle_to(p.direction_to(next_p))) > MAX_ANGLE_INBOUND_TO_OUTBOUND:
			splits.append(i)

	print("pass 1: ", splits)
	# any p of which the p_a bends in the opposite direction of the p_a' that came before it
	# or the difference in angle with the previous p_a(p[s_idx]) exceeds 45° will also become
	# the start of a new s_idx
	var cumulative_angle := 0.0
	var last_angle := 0.0
	var cumulative_distance := 0.0
	for i in range(1, pts.size()):
		var prev_p := pts[i - 1]
		var p := pts[i]
		var next_p := pts[i + 1] if i < pts.size() - 1 else pts[i]
		var cur_angle := prev_p.direction_to(p).angle_to(p.direction_to(next_p))
		cumulative_angle += cur_angle
		cumulative_distance += prev_p.distance_to(next_p)
		if (i not in splits and (absf(cumulative_angle) > MAX_CUMULATIVE_ANGLE_PER_SEGMENT
					or is_equal_approx(absf(cumulative_angle), MAX_CUMULATIVE_ANGLE_PER_SEGMENT)
					or (last_angle > 0.0 and cur_angle < 0.0)
					or (last_angle < 0.0 and cur_angle > 0.0)
		) and cumulative_distance > MIN_DISTANCE_BETWEEN_SEGMENT_STARTS):
			splits.append(i)
		if i in splits:
			cumulative_angle = 0.0
			cumulative_distance = 0.0
		last_angle = cur_angle
	print("pass 2: ", splits)
	splits.sort()
	return splits
