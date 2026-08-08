extends SceneTree

var failures := 0

func _initialize() -> void:
	test_ellipse_fill_and_closed_stroke()
	test_donut_keeps_hole()
	test_disjoint_shapes_stay_apart()
	test_island_inside_hole_survives()
	test_open_stroke_with_caps()
	test_stroke_against_the_contour_of_the_fill()
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
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


func total_area(polys : Array[PackedVector2Array]) -> float:
	var a := 0.0
	for p in polys:
		a += area(p)
	return a


func covers(polys : Array[PackedVector2Array], p : Vector2) -> bool:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func ellipse_points(radius : float) -> PackedVector2Array:
	var c := Curve2D.new()
	ScalableVectorShape2D.set_ellipse_points(c, Vector2(radius, radius) * 2.0)
	var pts := c.tessellate(5, 1.0)
	if pts[0].distance_to(pts[-1]) < 0.001:
		pts.remove_at(pts.size() - 1)
	return pts


# Reproduces what _update_assigned_nodes() feeds to the collision object for a
# closed shape with a fill and a stroke.
func test_ellipse_fill_and_closed_stroke() -> void:
	print("\n[1] closed shape, fill + stroke")
	var fill := ellipse_points(100.0)
	var strokes := Geometry2DUtil.calculate_polystroke(fill, 10.0, Geometry2D.END_JOINED, Geometry2D.JOIN_ROUND, 0.0)
	var unmerged : Array[PackedVector2Array] = []
	unmerged.append_array(strokes)
	unmerged.append(fill)

	var merged := Geometry2DUtil.union_polygons(unmerged)
	check("the unmerged set has more than one polygon", unmerged.size() > 1, "%d polygons" % unmerged.size())
	check("merged generates exactly one collider", merged.size() == 1, "%d polygons" % merged.size())
	var expected := PI * 110.0 * 110.0
	check("area equals the outline grown by half the stroke width",
			absf(total_area(merged) - expected) / expected < 0.01,
			"%.0f vs %.0f" % [total_area(merged), expected])
	check("centre is solid", covers(merged, Vector2.ZERO))
	check("point at r=105 is solid", covers(merged, Vector2(105, 0)))
	check("point at r=115 is outside", not covers(merged, Vector2(115, 0)))


# Reproduces _update_assigned_nodes_with_clips() for a shape with a cutout:
# the stroke is rebuilt from every contour of the clipped fill, holes included.
func test_donut_keeps_hole() -> void:
	print("\n[2] cutout (boolean hole), fill + stroke")
	var fill : Array[PackedVector2Array] = [ellipse_points(100.0)]
	var cutouts : Array[PackedVector2Array] = [ellipse_points(40.0)]
	var clipped := Geometry2DUtil.apply_clips_to_polygon(fill, cutouts,
			Geometry2D.PolyBooleanOperation.OPERATION_DIFFERENCE)

	var strokes : Array[PackedVector2Array] = []
	for polyline in Geometry2DUtil.calculate_outlines(clipped.duplicate()):
		strokes.append_array(Geometry2DUtil.calculate_polystroke(polyline, 10.0,
				Geometry2D.END_JOINED, Geometry2D.JOIN_ROUND, 0.0))

	var unmerged : Array[PackedVector2Array] = []
	unmerged.append_array(strokes)
	unmerged.append_array(clipped)

	# the fill is a ring of [40, 100]; the stroke is drawn on both of its contours,
	# so it covers [30, 50] and [90, 110]: the union is a ring of [30, 110]
	var merged := Geometry2DUtil.union_polygons(unmerged)
	check("the unmerged set has 6 polygons", unmerged.size() == 6, "%d polygons" % unmerged.size())
	check("merged slices the hole out with 2 colliders", merged.size() == 2, "%d polygons" % merged.size())
	var expected := PI * (110.0 * 110.0 - 30.0 * 30.0)
	check("area equals the ring grown by half the stroke width on both sides",
			absf(total_area(merged) - expected) / expected < 0.01,
			"%.0f vs %.0f" % [total_area(merged), expected])
	check("centre of the cutout stays hollow", not covers(merged, Vector2.ZERO))
	check("point at r=25 stays hollow", not covers(merged, Vector2(25, 0)))
	check("point at r=45 is solid (covered by the cutout's stroke)", covers(merged, Vector2(45, 0)))
	check("point at r=55 is solid", covers(merged, Vector2(55, 0)))
	check("point at r=105 is solid", covers(merged, Vector2(105, 0)))
	check("point at r=115 is outside", not covers(merged, Vector2(115, 0)))


func test_disjoint_shapes_stay_apart() -> void:
	print("\n[3] two shapes which do not touch")
	var a := ellipse_points(20.0)
	var b : PackedVector2Array = []
	for p in ellipse_points(20.0):
		b.append(p + Vector2(500, 0))
	var merged := Geometry2DUtil.union_polygons([a, b] as Array[PackedVector2Array])
	check("both are kept", merged.size() == 2, "%d polygons" % merged.size())
	check("area is preserved", absf(total_area(merged) - area(a) * 2.0) < 1.0)


# A shape enclosed by a ring, floating inside its hole, must survive the union.
func test_island_inside_hole_survives() -> void:
	print("\n[4] island floating inside a hole")
	var ring := Geometry2DUtil.calculate_polystroke(ellipse_points(100.0), 10.0,
			Geometry2D.END_JOINED, Geometry2D.JOIN_ROUND, 0.0)
	var island := ellipse_points(20.0)
	var input : Array[PackedVector2Array] = []
	input.append_array(ring)
	input.append(island)

	var merged := Geometry2DUtil.union_polygons(input)
	check("centre of the island is solid", covers(merged, Vector2.ZERO))
	check("gap between island and ring stays hollow", not covers(merged, Vector2(60, 0)))
	check("the ring itself is solid", covers(merged, Vector2(105, 0)))
	var expected := PI * (110.0 * 110.0 - 90.0 * 90.0) + PI * 20.0 * 20.0
	check("area equals ring + island",
			absf(total_area(merged) - expected) / expected < 0.02,
			"%.0f vs %.0f" % [total_area(merged), expected])


# An open curve: the stroke has caps and does not follow the chord which closes
# the fill, so the union cannot be reduced to "the fill grown by half the width".
func test_open_stroke_with_caps() -> void:
	print("\n[5] open curve, fill + capped stroke")
	var outline : PackedVector2Array = [Vector2(-100, 0), Vector2(0, -100), Vector2(100, 0)]
	var strokes := Geometry2DUtil.calculate_polystroke(outline, 10.0, Geometry2D.END_BUTT, Geometry2D.JOIN_MITER, 0.0)
	var unmerged : Array[PackedVector2Array] = []
	unmerged.append_array(strokes)
	unmerged.append(outline)

	var merged := Geometry2DUtil.union_polygons(unmerged)
	check("merged generates exactly one collider", merged.size() == 1, "%d polygons" % merged.size())
	check("inside of the fill is solid", covers(merged, Vector2(0, -20)))
	check("outside of the stroke is solid", covers(merged, Vector2(-55, -50)))
	check("beyond the stroke is outside", not covers(merged, Vector2(-75, -50)))
	check("below the closing chord is outside", not covers(merged, Vector2(0, 20)))
	check("area is at least the fill plus the outer half of the stroke",
			total_area(merged) > area(outline), "%.0f vs %.0f" % [total_area(merged), area(outline)])


# Two polygons can share an edge while describing it through a different chain of
# floating point operations - a stroke lying against the contour of its fill, for
# instance. Subtracting one from the other then leaves slivers behind, which are
# rounding noise and not holes: slicing the result around them would fragment it.
func test_stroke_against_the_contour_of_the_fill() -> void:
	print("\n[6] stroke lying against the contour of the fill")
	var fill := ellipse_points(100.0)
	var stroke_line := Geometry2D.offset_polygon(fill, 10.0, Geometry2D.JOIN_ROUND)[0]
	var strokes := Geometry2DUtil.calculate_polystroke(stroke_line, 10.0,
			Geometry2D.END_JOINED, Geometry2D.JOIN_ROUND, 0.0)
	var unmerged : Array[PackedVector2Array] = []
	unmerged.append_array(strokes)
	unmerged.append(fill)

	var merged := Geometry2DUtil.union_polygons(unmerged)
	check("merged generates exactly one collider", merged.size() == 1, "%d polygons" % merged.size())
	var expected := PI * 120.0 * 120.0
	check("area equals the fill plus the stroke",
			absf(total_area(merged) - expected) / expected < 0.01,
			"%.0f vs %.0f" % [total_area(merged), expected])
	check("centre is solid", covers(merged, Vector2.ZERO))
	check("just inside the shared edge is solid", covers(merged, Vector2(99, 0)))
	check("just outside the shared edge is solid", covers(merged, Vector2(101, 0)))
	check("point at r=115 is solid", covers(merged, Vector2(115, 0)))
	check("point at r=125 is outside", not covers(merged, Vector2(125, 0)))
