@tool
extends Object

# adapted from Python implementation of Philip J. Schneider's "Algorithm for Automatically Fitting Digitized Curves" from the book "Graphics Gems"
# at https://github.com/volkerp/fitCurves
class_name FitCurves


# evaluates cubic bezier at t, return point
static func bezier_q(ctrl_poly : PackedVector2Array, t : float) -> Vector2:
	return (1.0-t)**3 * ctrl_poly[0] + 3*(1.0-t)**2 * t * ctrl_poly[1] + 3*(1.0-t)* t**2 * ctrl_poly[2] + t**3 * ctrl_poly[3]


# evaluates cubic bezier first derivative at t, return point
static func bezier_qprime(ctrl_poly : PackedVector2Array, t : float) -> Vector2:
	return 3*(1.0-t)**2 * (ctrl_poly[1]-ctrl_poly[0]) + 6*(1.0-t) * t * (ctrl_poly[2]-ctrl_poly[1]) + 3*t**2 * (ctrl_poly[3]-ctrl_poly[2])


# evaluates cubic bezier second derivative at t, return point
static func bezier_qprimeprime(ctrl_poly : PackedVector2Array, t : float) -> Vector2:
	return 6*(1.0-t) * (ctrl_poly[2]-2*ctrl_poly[1]+ctrl_poly[0]) + 6*(t) * (ctrl_poly[3]-2*ctrl_poly[2]+ctrl_poly[1])

#
#static func reparameterize(bezier : PackedVector2Array, points : PackedVector2Array, parameters : Array[float]) -> Array[float]:
	#var result : Array[float] = []
	#for i in points.size():
		#var point := points[i]
		#var u := parameters[i]
		#result.append(newton_raphson_root_find(bezier, point, u))
	#return result


#static func newton_raphson_root_find(bez : PackedVector2Array, point : Vector2, u : float):
	#var d := bezier_q(bez, u)-point
	##   numerator = (d * bezier.qprime(bez, u)).sum()
	#var numerator : float = vec2_sum(d * bezier_qprime(bez, u))
	##   denominator =                     (bezier.qprime(bez, u)**2 +        d * bezier.qprimeprime(bez, u)).sum()
	#var denominator := vec2_sum(vec2_squared(bezier_qprime(bez, u)) + d * bezier_qprimeprime(bez, u))
#
	#if denominator == 0.0:
		#return u
	#else:
		#return u - numerator/denominator


static func chord_length_parameterize(points : PackedVector2Array) -> Array[float]:
	var u : Array[float] = [0.0]
	for i in range(1, points.size()):
		u.append(u[i-1] + linalg_norm(points[i] - points[i-1]))
	for i in u.size():
		u[i] = u[i] / u[-1]
	return u


static func compute_max_error(points : PackedVector2Array, bez : PackedVector2Array, parameters : Array[float]) -> Array:
	var max_dist := 0.0
	var split_point = points.size() / 2
	for i in points.size():
		var dist := linalg_norm(bezier_q(bez, parameters[i])-points[i]) ** 2
		if dist > max_dist:
			max_dist = dist
			split_point = i
	return [max_dist, split_point]


# from https://github.com/higgs-bosoff/godot-linalg/
static func _norm2_v(v: Vector2)->float:
	var ans = 0.0
	for i in 2:
		ans += pow(v[i], 2)
	return ans

# from https://github.com/higgs-bosoff/godot-linalg/
static func linalg_norm(v: Vector2)->float:
	return sqrt(_norm2_v(v))


static func run_assertions() -> void:
	var test_bez := PackedVector2Array([
			Vector2(1.1,2.1),
			Vector2(2.1,1.1),
			Vector2(3.2,2.3),
			Vector2(4.0,4.0)
	])
	var test_pts_coarse := PackedVector2Array([
			Vector2(1.1,2.1),
			Vector2(1.86,1.73),
			Vector2(2.62,2.03),
			Vector2(4.0,4.0)
	])
	var test_params_coarse : Array[float] = [0.0, 0.33, 0.67, 1.0]
	assert(bezier_q(test_bez, 0.75).is_equal_approx(Vector2(3.35, 2.845313)), "bezier_q")
	assert(bezier_qprime(test_bez, 0.75).is_equal_approx(Vector2(2.775, 4.03125)), "bezier_qprime")
	assert(bezier_qprimeprime(test_bez, 0.75).is_equal_approx(Vector2(-1.2, 5.55)), "bezier_qprimeprime")
	assert(is_equal_approx(linalg_norm(bezier_q(test_bez, 0.67) - Vector2(3.2, 2.3)), 0.25301258015552), "linalg_norm" )
	var max_dist_split_point = compute_max_error(test_pts_coarse, test_bez, test_params_coarse)
	assert(is_equal_approx(max_dist_split_point[0], 0.515957) and is_equal_approx(max_dist_split_point[1], 2.0), "compute_max_error")
	var clp_actual := chord_length_parameterize(test_pts_coarse)
	var clp_expected := [0.0, 0.20780757891225984, 0.4086791285720354, 1.0]
	for i in range(4):
		assert(is_equal_approx(clp_actual[i], clp_expected[i]), "chord_length_parameterize")
