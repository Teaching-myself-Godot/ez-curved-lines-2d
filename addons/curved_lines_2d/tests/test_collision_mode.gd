extends SceneTree

var failures := 0

const MODE_NAMES := {
	ScalableVectorShape2D.CollisionMode.MERGED: "MERGED",
	ScalableVectorShape2D.CollisionMode.FILL_ONLY: "FILL_ONLY",
	ScalableVectorShape2D.CollisionMode.STROKE_ONLY: "STROKE_ONLY",
}


func check(label : String, condition : bool, detail := "") -> void:
	if condition:
		print("  ok   - ", label, ("  (%s)" % detail) if detail else "")
	else:
		failures += 1
		print("  FAIL - ", label, ("  (%s)" % detail) if detail else "")


func make_shape(radius : float, with_fill : bool, with_stroke : bool, with_body : bool) -> ScalableVectorShape2D:
	var svs := ScalableVectorShape2D.new()
	svs.shape_type = ScalableVectorShape2D.ShapeType.ELLIPSE
	svs.size = Vector2(radius, radius) * 2.0
	svs.stroke_width = 20.0
	root.add_child(svs)
	if with_fill:
		svs.polygon = Polygon2D.new()
		svs.add_child(svs.polygon)
	if with_stroke:
		svs.line = Line2D.new()
		svs.add_child(svs.line)
	if with_body:
		svs.collision_object = StaticBody2D.new()
		svs.add_child(svs.collision_object)
	return svs


func active_polygons(svs : ScalableVectorShape2D) -> Array[PackedVector2Array]:
	var result : Array[PackedVector2Array] = []
	for ch in svs.collision_object.get_children():
		if ch is CollisionPolygon2D and not ch.disabled:
			result.append(ch.polygon)
	return result


func covers(polys : Array[PackedVector2Array], p : Vector2) -> bool:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func child_count(svs : ScalableVectorShape2D) -> int:
	return svs.collision_object.get_children().filter(func(c): return c is CollisionPolygon2D).size()


func run_modes(label : String, with_cutout : bool) -> void:
	print("\n[%s]" % label)
	for mode in MODE_NAMES:
		var svs := make_shape(100.0, true, true, true)
		if with_cutout:
			var cutout := make_shape(40.0, false, false, false)
			svs.clip_paths = [cutout] as Array[ScalableVectorShape2D]
		svs.collision_mode = mode
		svs._update_curve()
		var polys := active_polygons(svs)
		print("  %-16s -> %d collider(s), %d node(s)" % [MODE_NAMES[mode], polys.size(), child_count(svs)])
		match mode:
			ScalableVectorShape2D.CollisionMode.MERGED:
				check("  no redundant collider", polys.size() <= 2, "%d" % polys.size())
				check("  outer edge of the stroke is solid", covers(polys, Vector2(105, 0)))
				if with_cutout:
					check("  cutout is preserved", not covers(polys, Vector2.ZERO))
				else:
					check("  fill is solid", covers(polys, Vector2.ZERO))
			ScalableVectorShape2D.CollisionMode.FILL_ONLY:
				check("  outer edge of the stroke is NOT solid", not covers(polys, Vector2(105, 0)))
				check("  fill is solid", covers(polys, Vector2(95, 0)))
			ScalableVectorShape2D.CollisionMode.STROKE_ONLY:
				check("  stroke is solid", covers(polys, Vector2(105, 0)))
				check("  centre is hollow", not covers(polys, Vector2.ZERO))
		svs.free()


func test_surplus_nodes_are_reused() -> void:
	print("\n[surplus nodes]")
	# the stroke of a closed shape is a ring, which is sliced into 2 polygons,
	# where merging it with the fill needs only 1
	var svs := make_shape(100.0, true, true, true)
	svs.collision_mode = ScalableVectorShape2D.CollisionMode.STROKE_ONLY
	svs._update_curve()
	var created := child_count(svs)
	check("the stroke needs more than one collider", created > 1, "%d nodes" % created)
	svs.collision_mode = ScalableVectorShape2D.CollisionMode.MERGED
	svs._update_curve()
	check("surplus nodes are kept", child_count(svs) == created, "%d nodes" % child_count(svs))
	check("surplus nodes are disabled", active_polygons(svs).size() < created,
			"%d of %d active" % [active_polygons(svs).size(), created])
	for ch in svs.collision_object.get_children():
		if ch is CollisionPolygon2D and ch.disabled:
			check("  disabled node is hidden too", not ch.visible)
			break
	svs.collision_mode = ScalableVectorShape2D.CollisionMode.STROKE_ONLY
	svs._update_curve()
	check("nodes are reused when the count grows back", child_count(svs) == created
			and active_polygons(svs).size() == created, "%d nodes" % child_count(svs))
	svs.free()


func test_no_stroke_assigned() -> void:
	print("\n[no stroke assigned]")
	var svs := make_shape(100.0, true, false, true)
	svs.collision_mode = ScalableVectorShape2D.CollisionMode.MERGED
	svs._update_curve()
	check("MERGED falls back to the fill", active_polygons(svs).size() == 1
			and covers(active_polygons(svs), Vector2.ZERO))
	svs.collision_mode = ScalableVectorShape2D.CollisionMode.STROKE_ONLY
	svs._update_curve()
	check("STROKE_ONLY generates nothing", active_polygons(svs).is_empty())
	svs.free()


func test_no_fill_no_stroke() -> void:
	print("\n[neither fill nor stroke assigned]")
	var svs := make_shape(100.0, false, false, true)
	svs.collision_mode = ScalableVectorShape2D.CollisionMode.MERGED
	svs._update_curve()
	check("MERGED still generates the outline",
			active_polygons(svs).size() == 1 and covers(active_polygons(svs), Vector2.ZERO))
	svs.free()


func _process(_delta : float) -> bool:
	run_modes("ellipse with fill + stroke", false)
	run_modes("ellipse with fill + stroke + cutout", true)
	test_surplus_nodes_are_reused()
	test_no_stroke_assigned()
	test_no_fill_no_stroke()
	print("")
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
	return true
