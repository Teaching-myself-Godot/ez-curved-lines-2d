extends Node2D


## Only drawing polygons is fastest
@export var draw_fills := true

## Drawing strokes with cutouts requires extra compute, but still ok
@export var draw_strokes := true

## Redrawing navigation is fast, but would slow down agents
@export var draw_navigation := false

## Redrawing collision polygons is heavy
@export var draw_collision := false


var foobar := false
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		add_ellipse(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		add_clip_to_ellipses(event.position)


func add_clip_to_ellipses(at_pos: Vector2):
	var ellipse : ScalableVectorShape2D = null
	for ch in get_children():
		if ch is ScalableVectorShape2D and ch.shape_type == ScalableVectorShape2D.ShapeType.ELLIPSE and ch.clipped_polygon_has_point(at_pos):
			ellipse = ch

	if not ellipse:
		return

	foobar = not foobar
	var rect = ScalableVectorShape2D.new()
	rect.name = "ClipRect"
	rect.update_curve_at_runtime = true
	rect.shape_type = ScalableVectorShape2D.ShapeType.RECT
	rect.position = at_pos - ellipse.position
	rect.size = Vector2(200, 40) if foobar else Vector2(40, 200)
	rect.rx = 20
	rect.ry = 20
	ellipse.add_child(rect, true)
	ellipse.add_clip_path(rect)


func add_ellipse(at_pos: Vector2):
	var ellipse = ScalableVectorShape2D.new()
	# make sure it will rerender in game
	ellipse.name = "Ellipse"
	ellipse.update_curve_at_runtime = true
	ellipse.shape_type = ScalableVectorShape2D.ShapeType.ELLIPSE
	ellipse.position = at_pos
	ellipse.size = Vector2(500, 250)

	if draw_fills:
		# assign a Polygon2D as fill
		ellipse.polygon = Polygon2D.new()
		ellipse.polygon.color = Color.WHITE
		ellipse.add_child(ellipse.polygon)

	if draw_strokes:
		# assign a Line2D as stroke
		ellipse.line = Line2D.new()
		ellipse.stroke_color = Color.BLACK
		ellipse.add_child(ellipse.line)

	if draw_collision:
		# assign a collision object to hold new collision polygons
		ellipse.collision_object = StaticBody2D.new()
		ellipse.add_child(ellipse.collision_object)

	if draw_navigation:
		ellipse.navigation_region = NavigationRegion2D.new()
		ellipse.add_child(ellipse.navigation_region)

	add_child(ellipse, true)
