@tool
extends Object

# adapted from Python implementation of Philip J. Schneider's "Algorithm for Automatically Fitting Digitized Curves" from the book "Graphics Gems"
# at https://github.com/volkerp/fitCurves
class_name FitCurves


# evaluates cubic bezier at t, return point
func bezier_q(ctrl_poly : PackedVector2Array, t : float) -> Vector2:
	return (1.0-t)**3 * ctrl_poly[0] + 3*(1.0-t)**2 * t * ctrl_poly[1] + 3*(1.0-t)* t**2 * ctrl_poly[2] + t**3 * ctrl_poly[3]


# evaluates cubic bezier first derivative at t, return point
func bezier_qprime(ctrl_poly : PackedVector2Array, t : float) -> Vector2:
	return 3*(1.0-t)**2 * (ctrl_poly[1]-ctrl_poly[0]) + 6*(1.0-t) * t * (ctrl_poly[2]-ctrl_poly[1]) + 3*t**2 * (ctrl_poly[3]-ctrl_poly[2])


# evaluates cubic bezier second derivative at t, return point
func bezier_qprimeprime(ctrl_poly : PackedVector2Array, t : float) -> Vector2:
	return 6*(1.0-t) * (ctrl_poly[2]-2*ctrl_poly[1]+ctrl_poly[0]) + 6*(t) * (ctrl_poly[3]-2*ctrl_poly[2]+ctrl_poly[1])


func reparameterize(bezier : PackedVector2Array, points : PackedVector2Array, parameters : Array[float]) -> Array[float]:
	var result : Array[float] = []
	for i in points.size():
		var point := points[i]
		var u := parameters[i]
		result.append(newtonRaphsonRootFind(bezier, point, u))
	return result


func newtonRaphsonRootFind(bez : PackedVector2Array, point : Vector2, u : float):
	var d := bezier_q(bez, u)-point
	#   numerator = (d * bezier.qprime(bez, u)).sum()
	var numerator : float = vec2_sum(d * bezier_qprime(bez, u))
	#   denominator =                     (bezier.qprime(bez, u)**2 +        d * bezier.qprimeprime(bez, u)).sum()
	var denominator := vec2_sum(vec2_squared(bezier_qprime(bez, u)) + d * bezier_qprimeprime(bez, u))

	if denominator == 0.0:
		return u
	else:
		return u - numerator/denominator


func chordLengthParameterize(points : PackedVector2Array) -> Array[float]:
	var u := [0.0]
	for i in range(1, points.size()):
		u.append(u[i-1] + (points[i] - points[i-1]).normalized())
	for i in u.size():
		u[i] = u[i] / u[-1]

	return u


func vec2_sum(v : Vector2) -> float:
	return v.x + v.y


func vec2_squared(v : Vector2) -> Vector2:
	return Vector2(v.x ** 2, v.y ** 2)


func vec2_squared_length(v : Vector2) -> float:
	return v.x ** 2 + v.y ** 2


func computeMaxError(points : PackedVector2Array, bez : PackedVector2Array, parameters : Array[float]) -> Array:
	var max_dist := 0.0
	var split_point = points.size() / 2
	for i in points.size():
		var dist :=  vec2_squared_length((bezier_q(bez, parameters[i])-points[i]).normalized())
		if dist > max_dist:
			max_dist = dist
			split_point = i

	return [max_dist, split_point]
