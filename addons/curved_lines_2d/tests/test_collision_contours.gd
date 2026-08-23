extends SceneTree

# Reproduces both errors a contour can provoke once it reaches a CollisionPolygon2D.
#
# [1]-[4] `Convex decomposing failed!`, reported in #398 and #396.
#
# The boolean operations of Geometry2D hand back contours in which a vertex occurs twice
# in a row. The shape is the same - a zero length edge covers no surface - but Godot's
# triangulator cannot handle it: decompose_polygon_in_convex() bails out, which is what
# a CollisionPolygon2D calls when it builds its shapes. The error is logged every time
# the scene loads and every time the shape is recomputed, whether the node is enabled or
# hidden and disabled.
#
# _update_assigned_nodes() already dropped the closing vertex when it coincided with the
# first one; the duplicates in the middle of the contour are the ones that got through.
#
# [5] `Invalid polygon data, triangulation failed.`
#
# A boolean operation can also hand back a contour enclosing no surface at all. It is
# not a collider - it collides with nothing - and it cannot be triangulated, which the
# editor does to every CollisionPolygon2D in order to draw it. The result is that error
# on every single redraw, for as long as the node exists.

var failures := 0


# CollisionPolygon2D10 of a shape with two overlapping cutouts, read straight out of the
# saved scene. Three of its seventeen vertices repeat the one before them.
var from_a_saved_scene := PackedVector2Array([
	Vector2(286.457000732422, 200.233993530273), Vector2(281.188995361328, 196.292007446289),
	Vector2(275.733001708984, 192.207992553711), Vector2(275.639007568359, 192.121994018555),
	Vector2(266.139007568359, 183.363998413086), Vector2(266.139007568359, 140.733993530273),
	Vector2(268.255004882813, 140.287994384766), Vector2(268.390014648438, 140.259002685547),
	Vector2(268.528015136719, 140.246002197266), Vector2(268.528015136719, 140.246002197266),
	Vector2(278.819000244141, 139.238998413086), Vector2(278.819000244141, 139.238998413086),
	Vector2(278.912994384766, 139.229995727539), Vector2(279.007995605469, 139.227996826172),
	Vector2(279.007995605469, 139.227996826172), Vector2(281.188995361328, 139.180999755859),
	Vector2(286.457000732422, 139.067001342773),
])


func _initialize() -> void:
	test_a_contour_from_a_saved_scene()
	test_a_single_repeat_is_tolerated()
	test_a_clean_contour_is_left_alone()
	test_the_closing_vertex_is_dropped()
	test_contours_without_surface_get_no_collider()
	test_a_self_crossing_contour_is_resolved_into_lobes()
	print("")
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)


func check(label : String, condition : bool, detail := "") -> void:
	if condition:
		print("  ok   - ", label, ("  (%s)" % detail) if detail else "")
	else:
		failures += 1
		print("  FAIL - ", label, ("  (%s)" % detail) if detail else "")


func decomposes(poly : PackedVector2Array) -> bool:
	return not Geometry2D.decompose_polygon_in_convex(poly).is_empty()


func area(poly : PackedVector2Array) -> float:
	return Geometry2DUtil.get_polygon_area(poly)


# The case as it comes out of the plugin: a CollisionPolygon2D which logs an error on
# every load, and keeps logging it while hidden and disabled.
func test_a_contour_from_a_saved_scene() -> void:
	print("\n[1] a contour of a cutout, read out of a saved scene")
	var cleaned := Geometry2DUtil.remove_duplicate_points(from_a_saved_scene)
	check("three vertices repeat the one before them",
			from_a_saved_scene.size() - cleaned.size() == 3,
			"%d -> %d points" % [from_a_saved_scene.size(), cleaned.size()])
	check("Godot cannot decompose it as saved", not decomposes(from_a_saved_scene))
	check("it decomposes once the repeats are gone", decomposes(cleaned))
	check("the surface it covers is unchanged",
			absf(area(cleaned) - area(from_a_saved_scene)) < 0.000001,
			"%.6f vs %.6f" % [area(cleaned), area(from_a_saved_scene)])


# Why this is so hard to reproduce by hand: a repeated vertex on a shape you can draw is
# tolerated. The triangulator only gives up on contours that come out of overlapping
# cutouts, and only once several repeats accumulated in one of them - dropping a single
# repeat out of the three is not enough, which is why the whole contour has to be swept.
func test_a_single_repeat_is_tolerated() -> void:
	print("
[2] a repeat is only fatal in combination")
	var square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 0),
			Vector2(100, 100), Vector2(0, 100)])
	check("a square with a repeated vertex still decomposes", decomposes(square))
	var l_shape := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 50),
			Vector2(50, 50), Vector2(50, 50), Vector2(50, 100), Vector2(0, 100)])
	check("so does a concave one", decomposes(l_shape))
	for index in [9, 11, 14]:
		var one_less := from_a_saved_scene.duplicate()
		one_less.remove_at(index)
		check("dropping only the repeat at %d does not save the real contour" % index,
				not decomposes(one_less))
	check("dropping all three does",
			decomposes(Geometry2DUtil.remove_duplicate_points(from_a_saved_scene)))


# The fix may not touch contours which are already fine: no vertex is dropped for being
# merely close to its neighbour.
func test_a_clean_contour_is_left_alone() -> void:
	print("\n[3] a contour without repeats")
	var poly := PackedVector2Array([Vector2(0, 0), Vector2(0.01, 0), Vector2(100, 0.02),
			Vector2(100, 100), Vector2(0, 100)])
	var cleaned := Geometry2DUtil.remove_duplicate_points(poly)
	check("every vertex survives", cleaned == poly, "%d -> %d points" % [poly.size(), cleaned.size()])


# The closing vertex is a repeat of the first one, one lap further along.
func test_the_closing_vertex_is_dropped() -> void:
	print("\n[4] a contour closed by repeating its first vertex")
	var closed := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100),
			Vector2(0, 100), Vector2(0, 0)])
	var cleaned := Geometry2DUtil.remove_duplicate_points(closed)
	check("the closing vertex is dropped", cleaned.size() == 4, "%d points" % cleaned.size())
	check("the surface is unchanged", is_equal_approx(area(cleaned), 10000.0), "%.1f" % area(cleaned))


# A contour with no surface never becomes a CollisionPolygon2D, and the repeats are swept
# out of the ones that do.
func test_contours_without_surface_get_no_collider() -> void:
	print("
[5] contours which do not deserve a collider")
	var square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100),
			Vector2(0, 100)])
	var collinear := PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(100, 0)])
	var pinched := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(0, 0),
			Vector2(100, 0), Vector2(0, 0)])
	var contours : Array[PackedVector2Array] = [square, collinear, pinched,
			from_a_saved_scene]
	var usable := Geometry2DUtil.get_collidable_contours(contours)
	check("the two contours with surface survive", usable.size() == 2,
			"%d of %d kept" % [usable.size(), contours.size()])
	check("the collinear triangle is dropped", not usable.has(collinear))
	check("the pinched contour is dropped", not usable.has(pinched))
	for contour in usable:
		check("what is kept triangulates: %d pts" % contour.size(),
				not Geometry2D.triangulate_polygon(contour).is_empty())
	check("the square keeps its surface",
			is_equal_approx(Geometry2DUtil.get_polygon_area(usable[0]), 10000.0),
			"%.1f" % Geometry2DUtil.get_polygon_area(usable[0]))


# A shape dragged through itself encloses real surface but cannot be triangulated as it
# stands. normalize_contour() resolves the crossing into simple geometry - how many
# pieces come out is Clipper's business (lobes sharing only the crossing point can come
# back as a single self-touching contour) - so the fill and the colliders get geometry
# they can digest for every frame of the drag, covering the same surface.
func test_a_self_crossing_contour_is_resolved_into_lobes() -> void:
	print("
[6] a self-crossing contour with real surface")
	var figure_of_eight := PackedVector2Array([Vector2(0, 0), Vector2(100, 100),
			Vector2(100, 0), Vector2(0, 100)])
	check("as one contour it does not triangulate",
			Geometry2D.triangulate_polygon(figure_of_eight).is_empty())
	var pieces := Geometry2DUtil.normalize_contour(figure_of_eight)
	check("it resolves into simple geometry", not pieces.is_empty(), "%d pieces" % pieces.size())
	var total := 0.0
	for piece in pieces:
		check("piece of %d pts triangulates" % piece.size(),
				not Geometry2D.triangulate_polygon(piece).is_empty())
		total += Geometry2DUtil.get_polygon_area(piece)
	check("together they cover both lobes", is_equal_approx(total, 5000.0), "%.1f" % total)
	var square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100),
			Vector2(0, 100)])
	var untouched := Geometry2DUtil.normalize_contour(square)
	check("a simple contour comes back alone", untouched.size() == 1 and untouched[0] == square)
	var colliders := Geometry2DUtil.get_collidable_contours([figure_of_eight] as Array[PackedVector2Array])
	check("the colliders get resolved geometry", not colliders.is_empty(),
			"%d colliders" % colliders.size())
	for collider in colliders:
		check("collider of %d pts decomposes" % collider.size(),
				not Geometry2D.decompose_polygon_in_convex(collider).is_empty())
