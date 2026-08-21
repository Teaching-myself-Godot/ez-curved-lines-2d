extends SceneTree

var failures := 0

func _initialize() -> void:
	test_cutout_keeps_its_own_contour()
	test_peninsula_pinched_off_by_the_slice()
	test_island_floating_inside_a_cutout()
	test_shapes_which_do_not_touch()
	print("")
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)


func check(label : String, condition : bool, detail := "") -> void:
	if condition:
		print("  ok   - ", label, ("  (%s)" % detail) if detail else "")
	else:
		failures += 1
		print("  FAIL - ", label, ("  (%s)" % detail) if detail else "")


func area(poly : PackedVector2Array) -> float:
	return Geometry2DUtil.get_polygon_area(poly)


func ellipse_points(radius : float, offset := Vector2.ZERO) -> PackedVector2Array:
	var c := Curve2D.new()
	ScalableVectorShape2D.set_ellipse_points(c, Vector2(radius, radius) * 2.0)
	var pts := c.tessellate(5, 1.0)
	if pts[0].distance_to(pts[-1]) < 0.001:
		pts.remove_at(pts.size() - 1)
	var result : PackedVector2Array = []
	for p in pts:
		result.append(p + offset)
	return result


# Reproduces what _update_assigned_nodes_with_clips() feeds to calculate_outlines():
# the fill after the cutouts were applied, already sliced open around its holes.
func clipped_fill(fill : PackedVector2Array, cutouts : Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	return Geometry2DUtil.apply_clips_to_polygon([fill] as Array[PackedVector2Array], cutouts,
			Geometry2D.PolyBooleanOperation.OPERATION_DIFFERENCE)


func holes_of(contours : Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	return Array(contours.filter(Geometry2D.is_polygon_clockwise), TYPE_PACKED_VECTOR2_ARRAY, "", null)


# Contours come out outline-first, but which hole lands where depends on the order the
# polygons happened to merge in, so look them up by the surface they cover.
func has_contour_covering(contours : Array[PackedVector2Array], expected : float) -> bool:
	return contours.any(func(c : PackedVector2Array):
			return absf(area(c) - expected) / expected < 0.02)


# The stroke of a shape with a cutout is drawn along both of its contours, so the
# cutout has to come back out of the sliced fill as one closed loop.
func test_cutout_keeps_its_own_contour() -> void:
	print("\n[1] round cutout in a round fill")
	var clipped := clipped_fill(ellipse_points(100.0), [ellipse_points(40.0)] as Array[PackedVector2Array])
	var contours := Geometry2DUtil.calculate_outlines(clipped.duplicate())
	check("the fill arrives sliced in two", clipped.size() == 2, "%d polygons" % clipped.size())
	check("one outline and one hole come out", contours.size() == 2, "%d contours" % contours.size())
	check("exactly one of them is a hole", holes_of(contours).size() == 1)
	var expected := PI * 100.0 * 100.0
	check("the outline is the contour of the fill",
			absf(area(contours[0]) - expected) / expected < 0.01,
			"%.0f vs %.0f" % [area(contours[0]), expected])
	expected = PI * 40.0 * 40.0
	check("the hole is the contour of the cutout",
			absf(area(contours[1]) - expected) / expected < 0.01,
			"%.0f vs %.0f" % [area(contours[1]), expected])


# A C-shaped cutout leaves a peninsula of fill sticking into it. slice_polygon_vertical()
# cuts straight through the neck connecting it, so the fill arrives here as three
# polygons of which two only touch along that cut. Merging a _pair_ of them reports the
# hole of that pair, which still counts the peninsula as part of the cutout: reading the
# holes off the intermediate merges draws the stroke straight across the fill.
func test_peninsula_pinched_off_by_the_slice() -> void:
	print("\n[2] cutout leaving a peninsula of fill")
	var fill : PackedVector2Array = [
		Vector2(0, 0), Vector2(400, 0), Vector2(400, 300), Vector2(0, 300)
	]
	# a "C" opening to the left: its mouth is the neck holding the peninsula
	var cutout : PackedVector2Array = [
		Vector2(100, 50), Vector2(300, 50), Vector2(300, 250), Vector2(100, 250),
		Vector2(100, 200), Vector2(250, 200), Vector2(250, 100), Vector2(100, 100)
	]
	var clipped := clipped_fill(fill, [cutout] as Array[PackedVector2Array])
	var contours := Geometry2DUtil.calculate_outlines(clipped.duplicate())
	check("the slice separates the peninsula from the fill", clipped.size() == 3,
			"%d polygons" % clipped.size())
	check("one outline and one hole come out", contours.size() == 2, "%d contours" % contours.size())
	check("the outline is the contour of the fill",
			is_equal_approx(area(contours[0]), 120000.0), "%.0f vs 120000" % area(contours[0]))
	check("the hole is the contour of the cutout, not its bounding shape",
			is_equal_approx(area(contours[1]), 25000.0), "%.0f vs 25000" % area(contours[1]))
	# the slice runs down the middle of the cutout's bounding box, at x = 200, so this
	# is the piece of the peninsula it cuts loose from the rest of the fill
	check("the piece of peninsula cut loose by the slice stays out of the hole",
			not Geometry2D.is_point_in_polygon(Vector2(225, 150), contours[1]))
	check("the cutout itself is inside the hole",
			Geometry2D.is_point_in_polygon(Vector2(275, 150), contours[1]))


# An island floating inside a cutout bounds the fill just like the cutout does, so it
# is a contour of the shape in its own right and the stroke is drawn around it too.
func test_island_floating_inside_a_cutout() -> void:
	print("\n[3] island floating inside a cutout")
	var clipped := clipped_fill(ellipse_points(100.0), [ellipse_points(40.0)] as Array[PackedVector2Array])
	var with_island : Array[PackedVector2Array] = []
	with_island.append_array(clipped)
	with_island.append(ellipse_points(15.0))
	var contours := Geometry2DUtil.calculate_outlines(with_island.duplicate())
	check("outline, cutout and island all come out", contours.size() == 3,
			"%d contours" % contours.size())
	check("the island keeps its own contour",
			has_contour_covering(contours, PI * 15.0 * 15.0))
	check("the cutout is still the contour of the cutout",
			has_contour_covering(contours, PI * 40.0 * 40.0))
	check("the outline is still the contour of the fill",
			has_contour_covering(contours, PI * 100.0 * 100.0))


func test_shapes_which_do_not_touch() -> void:
	print("\n[4] two shapes which do not touch")
	var contours := Geometry2DUtil.calculate_outlines(
			[ellipse_points(20.0), ellipse_points(20.0, Vector2(500, 0))] as Array[PackedVector2Array])
	check("both are kept as an outline", contours.size() == 2, "%d contours" % contours.size())
	check("neither is reported as a hole", holes_of(contours).is_empty())
