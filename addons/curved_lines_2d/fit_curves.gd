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


static func fit_curve(points : PackedVector2Array, max_error := 10.0) -> Curve2D:
	var left_tangent = normalize(points[1] - points[0])
	var right_tangent = normalize(points[-2] - points[-1])
	var result := fit_cubic(points, left_tangent, right_tangent, max_error)
	var curve_2d := Curve2D.new()
	curve_2d.add_point(result[0][0])
	for i in range(1, result.size()):
		curve_2d.add_point(result[i][3])
		curve_2d.set_point_out(i-1, result[i][1] - result[i-1][0])
		curve_2d.set_point_in(i, result[i][2] - result[i][3])
	return curve_2d


static func fit_cubic(points : PackedVector2Array, left_tangent : Vector2, right_tangent : Vector2, error : float) -> Array[PackedVector2Array]:
	# Use heuristic if region only has two points in it
	if (len(points) == 2):
		var dist := linalg_norm(points[0] - points[1]) / 3.0
		var bez_curve := [points[0], points[0] + left_tangent * dist, points[1] + right_tangent * dist, points[1]]
		return [bez_curve]
	# Parameterize points, and attempt to fit curve
	var u := chord_length_parameterize(points)
	var bez_curve := generate_bezier(points, u, left_tangent, right_tangent)
	# Find max deviation of points to fitted curve
	var max_err_split_pt = compute_max_error(points, bez_curve, u)
	var max_error = max_err_split_pt[0]
	var split_point = max_err_split_pt[1]
	if max_error < error:
		return [bez_curve]
	# If error not too large, try some reparameterization and iteration
	if max_error < error**2:
		for i in range(20):
			var u_prime := reparameterize(bez_curve, points, u)
			bez_curve = generate_bezier(points, u_prime, left_tangent, right_tangent)
			max_err_split_pt = compute_max_error(points, bez_curve, u)
			max_error = max_err_split_pt[0]
			split_point = max_err_split_pt[1]
			if max_error < error:
				return [bez_curve]
			u = u_prime
	# Fitting failed -- split at max error point and fit recursively
	var beziers : Array[PackedVector2Array] = []
	var center_tangent := (points[split_point-1] - points[split_point+1]).normalized()
	beziers.append_array(fit_cubic(points.slice(0, split_point + 1), left_tangent, center_tangent, error))
	beziers.append_array(fit_cubic(points.slice(split_point, points.size()), -center_tangent, right_tangent, error))
	return beziers


static func generate_bezier(points : PackedVector2Array, parameters : Array[float], left_tangent : Vector2, right_tangent : Vector2) -> PackedVector2Array:
	var bez_curve : Array = [points[0], null, null, points[-1]]

	var A : Array[PackedVector2Array] = []
	for _i in parameters.size():
		A.append(PackedVector2Array([Vector2.ZERO, Vector2.ZERO]))

	for i in parameters.size():
		var u := parameters[i]
		A[i][0] = left_tangent  * 3*(1-u)**2 * u
		A[i][1] = right_tangent * 3*(1-u)	* u**2
	# Create the C and X matrices
	var C : PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	var X : Array[float] = [0.0, 0.0]
	for i in points.size():
		var point := points[i]
		var u := parameters[i]
		C[0][0] += A[i][0].dot(A[i][0])
		C[0][1] += A[i][0].dot(A[i][1])
		C[1][0] += A[i][0].dot(A[i][1])
		C[1][1] += A[i][1].dot(A[i][1])
		var tmp := point - bezier_q([points[0], points[0], points[-1], points[-1]], u)
		X[0] += A[i][0].dot(tmp)
		X[1] += A[i][1].dot(tmp)
	# Compute the determinants of C and X
	var det_C0_C1 := C[0][0] * C[1][1] - C[1][0] * C[0][1]
	var det_C0_X  := C[0][0] * X[1] - C[1][0] * X[0]
	var det_X_C1  := X[0] * C[1][1] - X[1] * C[0][1]
	# Finally, derive alpha values
	var alpha_l := 0.0 if det_C0_C1 == 0 else det_X_C1 / det_C0_C1
	var alpha_r := 0.0 if det_C0_C1 == 0 else det_C0_X / det_C0_C1
	# If alpha negative, use the Wu/Barsky heuristic (see text) */
	# (if alpha is 0, you get coincident control points that lead to
	# divide by zero in any subsequent NewtonRaphsonRootFind() call. */
	var seg_length := linalg_norm(points[0] - points[-1])
	var epsilon = 1.0e-6 * seg_length
	if alpha_l < epsilon or alpha_r < epsilon:
		# fall back on standard (probably inaccurate) formula, and subdivide further if needed.
		bez_curve[1] = bez_curve[0] + left_tangent * (seg_length / 3.0)
		bez_curve[2] = bez_curve[3] + right_tangent * (seg_length / 3.0)
	else:
		# First and last control points of the Bezier curve are
		# positioned exactly at the first and last data points
		# Control points 1 and 2 are positioned an alpha distance out
		# on the tangent vectors, left and right, respectively
		bez_curve[1] = bez_curve[0] + left_tangent * alpha_l
		bez_curve[2] = bez_curve[3] + right_tangent * alpha_r
	return PackedVector2Array(bez_curve)


static func reparameterize(bezier : PackedVector2Array, points : PackedVector2Array, parameters : Array[float]) -> Array[float]:
	var result : Array[float] = []
	for i in points.size():
		var point := points[i]
		var u := parameters[i]
		result.append(newton_raphson_root_find(bezier, point, u))
	return result


static func newton_raphson_root_find(bez : PackedVector2Array, point : Vector2, u : float):
	var d := bezier_q(bez, u)-point
	var numerator : float = vec2_sum(d * bezier_qprime(bez, u))
	var denominator := vec2_sum(vec2_squared(bezier_qprime(bez, u))) + vec2_sum(d * bezier_qprimeprime(bez, u))
	if denominator == 0.0:
		return u
	else:
		return u - numerator/denominator


static func vec2_sum(v : Vector2) -> float:
	return v.x + v.y


static func vec2_squared(v : Vector2) -> Vector2:
	return Vector2(v.x ** 2, v.y ** 2)


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
static func linalg_norm(v: Vector2) -> float:
	return sqrt(_norm2_v(v))

static func normalize(v : Vector2) -> Vector2:
	return v / linalg_norm(v)

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
	assert(is_equal_approx(newton_raphson_root_find(test_bez, Vector2(1.3,1.4), 0.4), 0.1509920), "newton_raphson_root_find")
	var rpm_actual := reparameterize(test_bez, test_pts_coarse, test_params_coarse)
	var rpm_expected := [0.0, 0.25366532841917966, 0.5316642025269103, 1.0]
	for i in range(4):
		assert(is_equal_approx(rpm_actual[i], rpm_expected[i]), "reparameterize")
	var gen_bez_expected := [Vector2(1.1, 2.1), Vector2(2.371229, 3.486795), Vector2(6.426891, 6.542458), Vector2(4.0, 4.0)]
	var gen_bez_actual := generate_bezier(test_pts_coarse, test_params_coarse, Vector2(1.1,1.2), Vector2(2.1, 2.2))
	for i in range(4):
		assert(gen_bez_actual[i].is_equal_approx(gen_bez_expected[i]), "generate_bezier")
	var fc_actual := fit_cubic(test_pts_coarse, Vector2(1.1,1.2), Vector2(2.1,2.2), 10.0)
	var fc_expected : Array[PackedVector2Array] = [
		PackedVector2Array([
			Vector2(1.1, 2.1),
			Vector2(2.371229, 3.486795),
			Vector2(6.426891, 6.542458),
			Vector2(4.0, 4.0)]
		)
	]
	for i in range(4):
		assert(fc_actual[0][i].is_equal_approx(fc_expected[0][i]), "fit_cubic")
	var big_poly := PackedVector2Array([Vector2(-50.0, -50.0),Vector2(-38.8125, -45.625),Vector2(-27.25, -42.5),Vector2(-15.3125, -40.625),Vector2(-3.0, -40.0),Vector2(9.6875, -40.625),Vector2(22.75, -42.5),Vector2(36.1875, -45.625),Vector2(50.0, -50.0),Vector2(51.8865, -48.6141),Vector2(53.4816, -47.2132),Vector2(54.8007, -45.7983),Vector2(55.859, -44.3699),Vector2(56.6719, -42.9289),Vector2(57.2549, -41.4761),Vector2(57.6232, -40.0121),Vector2(57.7922, -38.5377),Vector2(57.7773, -37.0537),Vector2(57.5939, -35.5608),Vector2(57.2572, -34.0598),Vector2(56.7827, -32.5515),Vector2(55.4816, -29.5157),Vector2(53.8135, -26.4596),Vector2(45.928, -14.1518),Vector2(44.2678, -11.0841),Vector2(42.9778, -8.03225),Vector2(42.5101, -6.51412),Vector2(42.1809, -5.0022),Vector2(42.0058, -3.49724),Vector2(42.0, -2.0),Vector2(42.1755, -0.382228),Vector2(42.5095, 1.22847),Vector2(42.9865, 2.83286),Vector2(43.5912, 4.43168),Vector2(45.1221, 7.61564),Vector2(46.9795, 10.7864),Vector2(55.2154, 23.4579),Vector2(56.8616, 26.6531),Vector2(58.097, 29.8712),Vector2(58.5222, 31.4908),Vector2(58.7986, 33.1183),Vector2(58.9109, 34.7546),Vector2(58.8436, 36.4005),Vector2(58.5815, 38.0566),Vector2(58.1091, 39.7237),Vector2(57.4112, 41.4026),Vector2(56.4723, 43.094),Vector2(55.2771, 44.7987),Vector2(53.8102, 46.5174),Vector2(52.0563, 48.2509),Vector2(50.0, 50.0),Vector2(47.3688, 47.7872),Vector2(46.0483, 46.8886),Vector2(44.7241, 46.1218),Vector2(43.3961, 45.4818),Vector2(42.064, 44.9634),Vector2(40.7276, 44.5617),Vector2(39.3867, 44.2715),Vector2(38.041, 44.0878),Vector2(36.6904, 44.0056),Vector2(33.9731, 44.1252),Vector2(31.2332, 44.59),Vector2(28.4688, 45.3594),Vector2(22.8589, 47.6501),Vector2(17.1289, 50.6738),Vector2(5.25, 57.625),Vector2(-0.928223, 60.905),Vector2(-7.28516, 63.623),Vector2(-10.5352, 64.6701),Vector2(-13.8354, 65.4553),Vector2(-17.1877, 65.9381),Vector2(-20.5938, 66.0781),Vector2(-24.0555, 65.8348),Vector2(-27.5747, 65.1677),Vector2(-31.1533, 64.0364),Vector2(-34.793, 62.4004),Vector2(-38.4957, 60.2192),Vector2(-42.2632, 57.4524),Vector2(-46.0974, 54.0595),Vector2(-50.0, 50.0),Vector2(-54.9219, 45.1563),Vector2(-59.1875, 40.125),Vector2(-62.7969, 34.9063),Vector2(-65.75, 29.5),Vector2(-68.0469, 23.9063),Vector2(-69.6875, 18.125),Vector2(-70.6719, 12.1563),Vector2(-71.0, 6.0),Vector2(-70.6719, -0.343749),Vector2(-69.6875, -6.875),Vector2(-68.0469, -13.5937),Vector2(-65.75, -20.5),Vector2(-59.1875, -34.875)])
	fc_expected = [
		PackedVector2Array([Vector2(-50., -50.), Vector2(-28.79012047, -26.8619496 ), Vector2( 47.28441152, -53.20113709), Vector2( 53.48160172, -47.21319962)]),
 		PackedVector2Array([Vector2( 53.48160172, -47.21319962), Vector2( 68.24541129, -32.94790101), Vector2( 41.17989258, -17.05383123), Vector2(42., -2.)]),
 		PackedVector2Array([Vector2(42., -2.), Vector2(42.50446432,  7.25990977), Vector2(50.88646428, 16.50735843), Vector2(55.2154007 , 23.45789909)]),
 		PackedVector2Array([Vector2(55.2154007 , 23.45789909), Vector2(57.92930341, 27.81534152), Vector2(61.67356174, 51.15477821), Vector2(50., 50.)]),
 		PackedVector2Array([Vector2(50., 50.), Vector2(35.29557554, 48.54540119), Vector2(35.63338103, 40.19158341), Vector2(17.12890053, 50.67380142)]),
 		PackedVector2Array([Vector2(17.12890053, 50.67380142), Vector2( 2.550817  , 58.93183654), Vector2(-13.61614136,  70.75967803), Vector2(-31.15329933,  64.03639984)]),
 		PackedVector2Array([Vector2(-31.15329933,  64.03639984), Vector2(-55.50165051,  54.70189201), Vector2(-73.27057936,  25.14807877), Vector2(-70.67189789,  -0.34374899)]),
 		PackedVector2Array([Vector2(-70.67189789,  -0.34374899), Vector2(-69.9817136 ,  -7.11412817), Vector2(-68.36996017, -14.2065523 ), Vector2(-65.75, -20.5 )]),
 		PackedVector2Array([Vector2(-65.75, -20.5 ), Vector2(-63.7256078 , -25.36282448), Vector2(-48.12601523, -23.28677786), Vector2(-59.1875, -34.875 )])
	]
	fc_actual = fit_cubic(big_poly, Vector2(1.1,1.2), Vector2(2.1,2.2), 10.0)
	assert(fc_actual.size() == fc_expected.size(), "fit_curves big, sizes don't match")
	for i in fc_expected.size():
		for j in fc_expected[i].size():
			if not fc_actual[i][j].is_equal_approx(fc_expected[i][j]):
				printerr("fc_expected[%d][%d]" % [i, j])
				printerr(fc_expected[i][j])
				printerr(fc_actual[i][j])
			else:
				print("matching")
	print(fit_curve(big_poly))
