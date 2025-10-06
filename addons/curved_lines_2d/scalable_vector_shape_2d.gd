@tool
extends Node2D
## A custom node that uses a Curve2D to control shapes like Line2D, Polygon2D with
## Original adapted code: https://www.hedberggames.com/blog/rendering-curves-in-godot
class_name ScalableVectorShape2D

## Emitted when a new set of points was calculated for the [member curve].
signal path_changed(new_points : PackedVector2Array)


## Emitted when all polygons are computed, also provides [member self] in order to keep track of the
## owning [ScalableVectorShape2D]
signal polygons_updated(polygons : Array[PackedVector2Array], poly_strokes : Array[PackedVector2Array], myself : ScalableVectorShape2D)

## Emitted when [member CanvasItem.set_notify_transform] was toggled on upon
## every transformation (used internally to handle changes in the position of cutouts)
signal transform_changed(ref_to_self : ScalableVectorShape2D)

## This signal is used internally in editor-mode to tell the DrawablePath2D tool that
## the instance of assigned [member line], [member polygon], or [member collision_polygon] has changed.
signal assigned_node_changed()

## This signal is emitted when the properties for describing an ellipse or rectangle change.
## Further reading: [member shape_type]
signal dimensions_changed()

signal clip_paths_changed()

## The constant used to convert a radius unit to the equivalent cubic Beziér control point length
const R_TO_CP = 0.5523

const CAP_MODE_MAP :  Dictionary[Line2D.LineCapMode, Geometry2D.PolyEndType]  = {
	Line2D.LINE_CAP_NONE: Geometry2D.END_BUTT,
	Line2D.LINE_CAP_ROUND: Geometry2D.END_ROUND,
	Line2D.LINE_CAP_BOX: Geometry2D.END_SQUARE,
}

const JOINT_MODE_MAP : Dictionary[Line2D.LineJointMode, Geometry2D.PolyJoinType] = {
	Line2D.LINE_JOINT_SHARP: Geometry2D.JOIN_MITER,
	Line2D.LINE_JOINT_BEVEL: Geometry2D.JOIN_SQUARE,
	Line2D.LINE_JOINT_ROUND: Geometry2D.JOIN_ROUND,
}



enum ShapeType {
	## Gives every point in the [member curve] a handle, as well as their in- and out- control points.
	## Ignores the [member size], [member offset], [member rx] and [member ry] properties when
	## drawing the shape.
	PATH,
	## Keeps the shape of the [member curve] as a rectangle, based on the [member offset],
	## [member size], [member rx] and [member ry].
	## Provides one handle to change [member size],	and two handles to change [member rx] and
	## [member ry] for rounded corners.
	## The [member offset] can change by using the pivot-tool in the 2D Editor
	RECT,
	## Keeps the shape of the [member curve] as an ellipse, based on the [member offset] and
	## [member size]
	## Provides one handle to change [member size]. The [member size] determines the radii of the
	## ellipse on the y- and x- axis, so [member rx] and [member ry] are always sync'ed with
	## [member size] (and vice-versa)
		## The [member offset] can change by using the pivot-tool in the 2D Editor
	ELLIPSE
}


enum CollisionObjectType {
	NONE,
	STATIC_BODY_2D,
	AREA_2D,
	ANIMATABLE_BODY_2D,
	RIGID_BODY_2D,
	CHARACTER_BODY_2D,
	PHYSICAL_BONE_2D
}

@export_group("Fill")
## The 'Fill' of a [ScalableVectorShape2D] is simply an instance of a [Polygon2D] node
## assigned to the `polygon` property.
## If you remove that [Polygon2D] node, you need to unassign it here as well, before
## you can add a new 'Fill' with the 'Add Fill' button
## The polygon's shape is controlled by this node's curve ([Curve2D]) property,
## it does _not_ have to be the child of this ScalableVectorShape2D
@export var polygon: Polygon2D:
	set(_poly):
		polygon = _poly
		assigned_node_changed.emit()

@export_group("Stroke")

## The color of the stroke, also sets the [member Line2D.default_color] of the
## [member line] and the [member Polygon2D.color] of the [member poly_stroke]
@export var stroke_color := Color.WHITE:
	set(_c):
		stroke_color = _c
		if is_instance_valid(line):
			line.default_color = _c
		if is_instance_valid(poly_stroke):
			poly_stroke.color = _c
		assigned_node_changed.emit()

## The width of the stroke, also sets the [member Line2D.width] of the [member line]
@export_range(0.5, 100.0, 0.5, "suffix:px", "or_greater", "or_less")
var stroke_width := 10.0:
	set(_sw):
		stroke_width = _sw
		if is_instance_valid(line):
			line.width = _sw
		assigned_node_changed.emit()

## The cap mode of the stroke start point, also sets the [member Line2D.begin_cap_mode]
## of the [member line].
## The [member poly_stroke] and [member collision_object] can only set _one_ cap mode
## using this property ([member begin_cap_mode]).
## Therefore the [member end_cap_mode] is ignored
@export var begin_cap_mode := Line2D.LINE_CAP_NONE:
	set(_bcm):
		begin_cap_mode = _bcm
		if is_instance_valid(line):
			line.begin_cap_mode = _bcm
		assigned_node_changed.emit()


## The cap mode of the stroke end point, also sets the [member Line2D.end_cap_mode] of the
## [member line].
## The [member poly_stroke] and [member collision_object] can only set _one_ cap mode
## using the [member begin_cap_mode]-property
## This property ([member end_cap_mode]) is ignored by them!
@export var end_cap_mode := Line2D.LINE_CAP_NONE:
	set(_ecm):
		end_cap_mode = _ecm
		if is_instance_valid(line):
			line.end_cap_mode = _ecm
		assigned_node_changed.emit()

## The line joint mode of the stroke, also sets the [member Line2D.line_joint_mode] of the
## [member line]
@export var line_joint_mode := Line2D.LINE_JOINT_SHARP:
	set(_ljm):
		line_joint_mode = _ljm
		if is_instance_valid(line):
			line.joint_mode = _ljm
		assigned_node_changed.emit()

## The 'Stroke' of a [ScalableVectorShape2D] is simply an instance of a [Line2D] node
## assigned to the `line` property.
## If you remove that Line2D node, you need to unassign it here as well, before
## you can add a new 'Line2D Stroke' with the 'Add Line2D Stroke' button
## The line's shape is controlled by this node's curve ([Curve2D]) pproperty, it
## does _not_ have to be the child of this [ScalableVectorShape2D]
@export var line: Line2D:
	set(_line):
		line = _line
		assigned_node_changed.emit()

## The 'Stroke' of a [ScalableVectorShape2D] can be an instance of a [Polygon2D] node
## assigned to the `poly_stroke` property.
## If you remove that Polygon2D node, you need to unassign it here as well, before
## you can add a new 'Poly Stroke' with the 'Add Polygon2D Stroke' button
## The line's shape is controlled by this node's curve ([Curve2D]) pproperty, it
## does _not_ have to be the child of this [ScalableVectorShape2D]
@export var poly_stroke: Polygon2D:
	set(_ps):
		poly_stroke = _ps
		assigned_node_changed.emit()


@export_group("Collision")
## The [CollisionObject2D] containing the [CollisionPolygon2D] node(s) generated
## by this shape
@export var collision_object: CollisionObject2D:
	set(_coll):
		collision_object = _coll
		assigned_node_changed.emit()


@export_subgroup("Collision Polygon2D*")
## The CollisionPolygon2D controlled by this node's curve property
## @deprecated: Use [member collision_object] instead.
@export var collision_polygon: CollisionPolygon2D:
	set(_poly):
		collision_polygon = _poly
		assigned_node_changed.emit()

@export_group("Navigation")
@export var navigation_region: NavigationRegion2D:
	set(_nav):
		navigation_region = _nav
		assigned_node_changed.emit()


## Controls the paramaters used to divide up the line  in segments.
## These settings are prefilled with the default values.
@export_group("Curve settings")
## The [Curve2D] that dynamically triggers updates of the shapes assigned to this node
## Changes to this curve will also emit the path_changed signal with the updated points array
@export var curve: Curve2D = Curve2D.new():
	set(_curve):
		curve = _curve if _curve != null else Curve2D.new()
		assigned_node_changed.emit()

## Controls whether the path is treated as static (only update in editor) or dynamic (can be updated during runtime)
## If you set this to true, be alert for potential performance issues
@export var update_curve_at_runtime: bool = false

## Controls how many subdivisions a curve segment may face before it is considered approximate enough.
## Each subdivision splits the segment in half, so the default 5 stages may mean up to 32 subdivisions
## per curve segment. Increase with care!
@export_range(1, 10) var max_stages : int = 5:
	set(_max_stages):
		max_stages = _max_stages
		assigned_node_changed.emit()

## Controls how many degrees the midpoint of a segment may deviate from the real curve, before the
## segment has to be subdivided.
@export_range(0.0, 180.0) var tolerance_degrees := 4.0:
	set(_tolerance_degrees):
		tolerance_degrees = _tolerance_degrees
		assigned_node_changed.emit()

## Manages the line segments which should be treated as arcs in stead of Bézier
## curves, see [class ScalableArc] for arc properties
@export var arc_list : ScalableArcList = ScalableArcList.new():
	set(_arc_list):
		arc_list = _arc_list if _arc_list != null else ScalableArcList.new()
		assigned_node_changed.emit()


## You can assign a [class Node2D] to a point in the curve (by point index) in order to control
## that [class Node2D]'s [member Node2D.position]: it's global position will be set exactly to the
## curve point's global position
@export var glue_map : Dictionary[int, Node2D] = {}:
	set(_map):
		glue_map = _map
		for p_idx in glue_map.keys():
			if p_idx < 0 or p_idx >= curve.point_count:
				printerr("Warning: point index key for glue_map not present in curve: ", p_idx)
		assigned_node_changed.emit()


@export_group("Masking")
## Holds the list of shapes used to make cutouts out of this shape, or
## clippings of this shape when their [member use_interect_when_clipping]
## is flagged on
@export var clip_paths : Array[ScalableVectorShape2D] = []:
	set(_clip_paths):
		clip_paths = _clip_paths if clip_paths != null else []
		for i in clip_paths.size():
			if clip_paths[i] == self:
				clip_paths[i] = null
		clip_paths_changed.emit()

## When this shape is used as a cutout, this tells the parent shape to use
## the  [method Geometry2D.intersect_polygons] operation in stead of the
## [method Geometry2D.clip_polygons] operation
@export var use_interect_when_clipping := false:
	set(flag):
		if flag:
			use_union_in_stead_of_clipping = false
		use_interect_when_clipping = flag
		path_changed.emit()

## When this shape is used as a cutout, this tells the parent shape to use
## the  [method Geometry2D.intersect_polygons] operation in stead of the
## [method Geometry2D.clip_polygons] operation
@export var use_union_in_stead_of_clipping := false:
	set(flag):
		if flag:
			use_interect_when_clipping = false
		use_union_in_stead_of_clipping = flag
		path_changed.emit()


@export_group("Shape Type Settings")
## Determines what handles are shown in the editor and how the [member curve] is (re)drawn on changing
## properties [member size], [member offset], [member rx], and [member ry].
@export var shape_type := ShapeType.PATH:
	set(st):
		shape_type = st
		if st == ShapeType.PATH:
			assigned_node_changed.emit()
		else:
			if shape_type == ShapeType.RECT:
				rx = 0.0
				ry = 0.0
			dimensions_changed.emit()

## The Ellipse/Rect's center relative to its pivot
@export var offset : Vector2 = Vector2(0.0, 0.0):
	set(ofs):
		offset = ofs
		dimensions_changed.emit()

## The natural (unscaled) size of the Ellipse/Rect
@export var size : Vector2 = Vector2(100.0, 100.0):
	set(sz):
		if sz.x < 0:
			sz.x = 0.001
		if sz.y < 0:
			sz.y = 0.001
		if shape_type == ShapeType.RECT:
			if sz.x < rx * 2.001:
				sz.x = rx * 2.001
			if sz.y < ry * 2.001:
				sz.y = ry * 2.001
			size = sz
			dimensions_changed.emit()
		elif shape_type == ShapeType.ELLIPSE:
			size = sz
			rx = sz.x * 0.5
			ry = sz.y * 0.5

## The rotation of the Rect/Ellipse's points relative to its natural center
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var spin := 0.0:
	set(a):
		spin = a
		dimensions_changed.emit()

## The Ellipse's radius / the Rect's rounded corder along the x-axis.
@export var rx : float = 0.0:
	set(_rx):
		rx = _rx if _rx > 0 else 0
		if shape_type == ShapeType.RECT:
			if rx > size.x * 0.49:
				rx = size.x * 0.49
		dimensions_changed.emit()

## The Ellipse's radius / the Rect's rounded corder along the y-axis.
@export var ry : float = 0.0:
	set(_ry):
		ry = _ry if _ry > 0 else 0
		if shape_type == ShapeType.RECT:
			if ry > size.y * 0.49:
				ry = size.y * 0.49
		dimensions_changed.emit()

@export_group("Editor settings")
## The [Color] used to draw the this shape's curve in the editor
@export var shape_hint_color := Color.LIME_GREEN
## When this field is checked, the 'Strokes', 'Fills' and 'Collisions' created
## with the 'Add ...' buttons will be locked from transforming to prevent
## inadvertently changing them, whilst the idea is that [ScalableVectorShape2D]
## controls them
@export var lock_assigned_shapes := true

@export_group("Export Options")
@export var show_export_options := true

var cached_outline : PackedVector2Array = []
var cached_clipped_polygons : Array[PackedVector2Array] = []
var cached_poly_strokes : Array[PackedVector2Array] = []

var should_update_curve := false

# Wire up signals at runtime
func _ready():
	if update_curve_at_runtime:
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)
		if not arc_list.changed.is_connected(curve_changed):
			arc_list.changed.connect(curve_changed)
		if not clip_paths_changed.is_connected(_on_clip_paths_changed):
			clip_paths_changed.connect(_on_clip_paths_changed)
			_on_clip_paths_changed()
	if not dimensions_changed.is_connected(_on_dimensions_changed):
		dimensions_changed.connect(_on_dimensions_changed)


# Wire up signals on enter tree for the editor
func _enter_tree():
	# ensure backward compatibility by overriding stroke properties by line's properties
	if is_instance_valid(line):
		if stroke_color != line.default_color:
			stroke_color = line.default_color
		if stroke_width != line.width:
			stroke_width = line.width
		if begin_cap_mode != line.begin_cap_mode:
			begin_cap_mode = line.begin_cap_mode
		if end_cap_mode != line.end_cap_mode:
			end_cap_mode = line.end_cap_mode
		if line_joint_mode != line.joint_mode:
			line_joint_mode = line.joint_mode
	# ensure forward compatibility by assigning the default ShapeType
	if shape_type == null:
		shape_type = ShapeType.PATH
	# ensure forward compatibility by assigning the default arc_list
	if arc_list == null:
		arc_list = ScalableArcList.new()
	# ensure forward compatibility by assigning an empty array to clip_paths
	if clip_paths == null:
		clip_paths = []
	# ensure forward compatibility by assigning an empty dict to glue_map
	if glue_map == null:
		glue_map = {}

	if Engine.is_editor_hint():
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)
		if not arc_list.changed.is_connected(curve_changed):
			arc_list.changed.connect(curve_changed)
		if not assigned_node_changed.is_connected(_on_assigned_node_changed):
			assigned_node_changed.connect(_on_assigned_node_changed)
		if not clip_paths_changed.is_connected(_on_clip_paths_changed):
			clip_paths_changed.connect(_on_clip_paths_changed)
			_on_clip_paths_changed()
	# handles update when reparenting
	if update_curve_at_runtime:
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)
		if not arc_list.changed.is_connected(curve_changed):
			arc_list.changed.connect(curve_changed)
		if not clip_paths_changed.is_connected(_on_clip_paths_changed):
			clip_paths_changed.connect(_on_clip_paths_changed)
			_on_clip_paths_changed()
	# updates the curve points when size, offset, rx, or ry prop changes
	# (used for ShapeType.RECT and ShapeType.ELLIPSE)
	if not dimensions_changed.is_connected(_on_dimensions_changed):
		dimensions_changed.connect(_on_dimensions_changed)
	_on_dimensions_changed()

# Clean up signals (ie. when closing scene) to prevent error messages in the editor
func _exit_tree():
	if curve.changed.is_connected(curve_changed):
		curve.changed.disconnect(curve_changed)
	if arc_list.changed.is_connected(curve_changed):
		arc_list.changed.disconnect(curve_changed)


func _process(_delta: float) -> void:
	if should_update_curve:
		_update_curve()
		should_update_curve = false


func _on_clip_paths_changed():
	for cp in clip_paths:
		if is_instance_valid(cp) and not cp.path_changed.is_connected(_on_assigned_node_changed):
			cp.path_changed.connect(_on_assigned_node_changed)
			cp.transform_changed.connect(_on_assigned_node_changed)
			cp.tree_entered.connect(_on_assigned_node_changed)
			cp.tree_exited.connect(func(): if is_inside_tree(): _on_assigned_node_changed())
			if Engine.is_editor_hint() or update_curve_at_runtime:
				cp.set_notify_local_transform(true)
				if not cp in get_children():
					set_notify_local_transform(true)
					transform_changed.connect(func(_x): curve_changed())
	_on_assigned_node_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		transform_changed.emit(self)


func _on_dimensions_changed():
	if shape_type == ShapeType.RECT:
		var width = size.x
		var height = size.y
		# curve is passed by reference to trigger changed on existing instance
		set_rect_points(curve, width, height, rx, ry, offset, spin)
	elif shape_type == ShapeType.ELLIPSE:
		# curve is passed by reference to trigger changed on existing instance
		set_ellipse_points(curve, size, offset, spin)


func _on_assigned_node_changed(_x : Variant = null):
	if Engine.is_editor_hint() or update_curve_at_runtime:
		if not curve.changed.is_connected(curve_changed):
			curve.changed.connect(curve_changed)
		if not arc_list.changed.is_connected(curve_changed):
			arc_list.changed.connect(curve_changed)

	if lock_assigned_shapes:
		if is_instance_valid(line):
			line.set_meta("_edit_lock_", true)
		if is_instance_valid(poly_stroke):
			poly_stroke.set_meta("_edit_lock_", true)
		if is_instance_valid(polygon):
			polygon.set_meta("_edit_lock_", true)
		if is_instance_valid(collision_polygon):
			collision_polygon.set_meta("_edit_lock_", true)
		if is_instance_valid(collision_object):
			collision_object.set_meta("_edit_lock_", true)
		if is_instance_valid(navigation_region):
			navigation_region.set_meta("_edit_lock_", true)
	curve_changed()


## Exposes assigned_node_changed signal to outside callers
func notify_assigned_node_change():
	assigned_node_changed.emit()


func tessellate() -> PackedVector2Array:
	if not cached_outline.is_empty():
		return cached_outline
	if not arc_list or arc_list.arcs.is_empty():
		return curve.tessellate(max_stages, tolerance_degrees)
	var poly_points = []
	var arc_starts := (arc_list.arcs
		.filter(func(a): return a != null)
		.map(func(a : ScalableArc): return a.start_point)
	)
	for p_idx in curve.point_count - 1:
		if p_idx in arc_starts:
			var seg := _get_curve_segment(p_idx)
			var arc = arc_list.get_arc_for_point(p_idx)
			if arc:
				var seg_points := tessellate_arc_segment(seg.get_point_position(0), arc.radius,
						arc.rotation_deg, arc.large_arc_flag, arc.sweep_flag, seg.get_point_position(1))
				for i in seg_points.size():
					if i == 0 and not poly_points.is_empty():
						continue
					poly_points.append(seg_points[i])
			else:
				printerr("Illegal state: there should be an arc int arc_list with start_point=%d - (%s)" % [p_idx, name])
				if poly_points.is_empty():
					poly_points.append(seg.get_point_position(0))
				poly_points.append(seg.get_point_position(1))
		else:
			var seg_points := _get_curve_segment(p_idx).tessellate(max_stages, tolerance_degrees)
			for i in seg_points.size():
				if i == 0 and not poly_points.is_empty():
					continue
				poly_points.append(seg_points[i])
	return poly_points


## Redraw the line based on the new curve, using its tessellate method
func curve_changed():
	if (not is_instance_valid(line) and not is_instance_valid(polygon)
			and not is_instance_valid(poly_stroke)
			and not is_instance_valid(collision_polygon)
			and not is_instance_valid(collision_object)
			and not is_instance_valid(navigation_region)
			and not path_changed.has_connections()
			and not polygons_updated.has_connections()):
		# guard against needlessly invoking expensive tessellate operation
		return
	should_update_curve = true


func _update_curve():
	# recalculate the polygon points for this shape based on curve and arc_list
	cached_outline.clear()
	cached_poly_strokes.clear()
	cached_outline.append_array(self.tessellate())
	# emit updated path to listeners
	path_changed.emit(cached_outline)

	for p_idx in glue_map.keys():
		if p_idx > -1 and p_idx < curve.point_count and is_instance_valid(glue_map[p_idx]):
			glue_map[p_idx].global_position = to_global(curve.get_point_position(p_idx))


	var polygon_points := cached_outline.duplicate()
	# Fixes cases start- and end-node are so close to each other that
	# polygons won't fill and closed lines won't cap nicely
	if (polygon_points.size() > 0 and
			polygon_points[0].distance_to(polygon_points[polygon_points.size()-1]) < 0.001):
		polygon_points.remove_at(polygon_points.size() - 1)

	var valid_clip_paths : Array[ScalableVectorShape2D] = (clip_paths
			.filter(func(cp): return is_instance_valid(cp))
			.filter(func(cp : Node2D): return cp.is_inside_tree())
	)

	if clip_paths.is_empty():
		_update_assigned_nodes(polygon_points)
		polygons_updated.emit(
			Array([cached_outline] if is_instance_valid(polygon) else [], TYPE_PACKED_VECTOR2_ARRAY, "", null),
			cached_poly_strokes, self)
	else:
		_update_assigned_nodes_with_clips(polygon_points, valid_clip_paths)
		polygons_updated.emit(cached_clipped_polygons if is_instance_valid(polygon) else Array([], TYPE_PACKED_VECTOR2_ARRAY, "", null), cached_poly_strokes, self)


func _update_assigned_nodes(polygon_points : PackedVector2Array) -> void:
	var collision_polygons : Array[PackedVector2Array] = []
	var navigation_polygons : Array[PackedVector2Array] = []
	# calculate stroke as polygon and cache it

	if (is_instance_valid(poly_stroke) or (is_instance_valid(line) and is_instance_valid(collision_object)) or (is_instance_valid(line) and is_instance_valid(navigation_region))) and not cached_outline.size() < 2:
		var cap_mode := Geometry2D.END_JOINED if is_curve_closed() else CAP_MODE_MAP[begin_cap_mode]
		var result := Geometry2DUtil.calculate_polystroke(cached_outline,
				stroke_width * 0.5, cap_mode, JOINT_MODE_MAP[line_joint_mode])
		cached_poly_strokes = result
		# add to list of updated collision polygons
		if is_instance_valid(collision_object):
			collision_polygons.append_array(cached_poly_strokes)
		if is_instance_valid(navigation_region):
			navigation_polygons.append_array(cached_poly_strokes)

	#  i. if there is a fill assigned, also generate collision polygon for the entire outline
	# ii. if there is no fill assigned and no stroke assigned, we assume the user _does_ want nav and collision
	if is_instance_valid(polygon) or (collision_polygons.is_empty() and not is_instance_valid(polygon)):
		collision_polygons.append(polygon_points)
		navigation_polygons.append(polygon_points)

	if is_instance_valid(line):
		line.points = polygon_points
		line.closed = is_curve_closed()
	if is_instance_valid(poly_stroke):
		var polygon_indices : Array = []
		var poly := Geometry2DUtil.get_polygon_indices(cached_poly_strokes, polygon_indices)
		poly_stroke.polygon = poly
		poly_stroke.polygons = polygon_indices
		_update_polygon_texture(poly_stroke, true)
	if is_instance_valid(polygon):
		polygon.polygons.clear()
		polygon.polygon = polygon_points
		_update_polygon_texture()
	if is_instance_valid(collision_polygon):
		collision_polygon.polygon = polygon_points
	if is_instance_valid(collision_object):
		var existing = collision_object.get_children().filter(func(ch): return ch is CollisionPolygon2D)
		for idx in existing.size():
			if idx >= collision_polygons.size():
				existing[idx].hide()
				existing[idx].disabled = true
		for polygon_index in collision_polygons.size():
			if polygon_index >= existing.size():
				existing.append(_make_new_collision_polygon_2d())
			existing[polygon_index].polygon = collision_polygons[polygon_index]
			existing[polygon_index].show()
			existing[polygon_index].disabled = false

	if is_instance_valid(navigation_region):
		var navigation_poly = NavigationPolygon.new()
		for poly_points in navigation_polygons:
			navigation_poly.add_outline(poly_points)
		NavigationServer2D.bake_from_source_geometry_data(navigation_poly, NavigationMeshSourceGeometryData2D.new())
		navigation_region.navigation_polygon = navigation_poly


func add_clip_path(svs : ScalableVectorShape2D):
	clip_paths.append(svs)
	_on_clip_paths_changed()


func _update_polygon_texture(poly := polygon, grow := false):
	if poly.texture is GradientTexture2D or poly.texture is ImageTexture:
		var box := get_bounding_rect().grow(0.5 * stroke_width) if grow else get_bounding_rect()
		poly.texture_offset = -box.position if grow else -box.position
		if poly.texture is GradientTexture2D:
			poly.texture.width = 1 if box.size.x < 1 else box.size.x
			poly.texture.height = 1 if box.size.y < 1 else box.size.y
		else:
			if not poly.texture_repeat:
				poly.texture_scale = poly.texture.get_size() / box.size


func _update_assigned_nodes_with_clips(polygon_points : PackedVector2Array, valid_clip_paths : Array[ScalableVectorShape2D]) -> void:

	var merges := valid_clip_paths.filter(func(cp : ScalableVectorShape2D): return cp.use_union_in_stead_of_clipping)
	var clips := valid_clip_paths.filter(func(cp : ScalableVectorShape2D): return cp.use_interect_when_clipping)
	var cutouts := valid_clip_paths.filter(func(cp : ScalableVectorShape2D): return not cp.use_interect_when_clipping and not cp.use_union_in_stead_of_clipping)

	var merge_results := Geometry2DUtil.apply_clips_to_polygon(
		[polygon_points],
		Array(merges.map(_clip_path_to_local), TYPE_PACKED_VECTOR2_ARRAY, "", null),
		Geometry2D.PolyBooleanOperation.OPERATION_UNION
	)
	var cutout_results := Geometry2DUtil.apply_clips_to_polygon(
		merge_results,
		Array(cutouts.map(_clip_path_to_local), TYPE_PACKED_VECTOR2_ARRAY, "", null),
		Geometry2D.PolyBooleanOperation.OPERATION_DIFFERENCE
	)

	var intersect_results_polystroke : Array[PackedVector2Array] = []
	if (is_instance_valid(poly_stroke) or (is_instance_valid(line) and is_instance_valid(collision_object)) or (is_instance_valid(line) and is_instance_valid(navigation_region))) and not cached_outline.size() < 2:
		var cutout_result_polylines : Array[PackedVector2Array] = (
				Geometry2DUtil.calculate_outlines(cutout_results.duplicate())
					if is_instance_valid(line) or is_instance_valid(poly_stroke) else
				[]
		)
		var polystroke_result : Array[PackedVector2Array] = []
		for polyline in cutout_result_polylines:
			polystroke_result.append_array(Geometry2DUtil.calculate_polystroke(polyline,
					stroke_width * 0.5, Geometry2D.END_JOINED, JOINT_MODE_MAP[line_joint_mode]))
		intersect_results_polystroke = Geometry2DUtil.apply_clips_to_polygon(
			polystroke_result,
			Array(clips.map(_clip_path_to_local), TYPE_PACKED_VECTOR2_ARRAY, "", null),
			Geometry2D.PolyBooleanOperation.OPERATION_INTERSECTION
		)

	var intersect_results_fill_polygon := Geometry2DUtil.apply_clips_to_polygon(
		cutout_results,
		Array(clips.map(_clip_path_to_local), TYPE_PACKED_VECTOR2_ARRAY, "", null),
		Geometry2D.PolyBooleanOperation.OPERATION_INTERSECTION
	)

	cached_poly_strokes = intersect_results_polystroke
	cached_clipped_polygons = intersect_results_fill_polygon

	var collision_polygons : Array[PackedVector2Array] = []
	if is_instance_valid(collision_object):
		collision_polygons.append_array(cached_poly_strokes)
	if is_instance_valid(polygon) or (collision_polygons.is_empty() and not is_instance_valid(polygon)):
		collision_polygons.append_array(cached_clipped_polygons)
	var navigation_polygons : Array[PackedVector2Array] = []
	if is_instance_valid(navigation_region):
		navigation_polygons.append_array(cached_poly_strokes)
	if is_instance_valid(polygon) or (navigation_polygons.is_empty() and not is_instance_valid(polygon)):
		navigation_polygons.append_array(cached_clipped_polygons)

	if is_instance_valid(line):
		if cached_clipped_polygons.is_empty():
			line.hide()
		else:
			var polylines := Geometry2DUtil.calculate_outlines(cached_clipped_polygons.duplicate())
			line.show()
			line.points = polylines.pop_front()
			# FIXME: closes the loop when original line is not closed
			line.closed = true
			var existing = line.get_children().filter(func(c): return c is Line2D)
			for idx in existing.size():
				if idx >= polylines.size():
					existing[idx].hide()
			for polyline_index in polylines.size():
				if polyline_index >= existing.size():
					existing.append(_make_new_line_2d())
				existing[polyline_index].points = polylines[polyline_index]
				existing[polyline_index].width = line.width
				existing[polyline_index].begin_cap_mode = line.begin_cap_mode
				existing[polyline_index].end_cap_mode = line.end_cap_mode
				existing[polyline_index].joint_mode = line.joint_mode
				existing[polyline_index].default_color = line.default_color
				existing[polyline_index].show()
	if is_instance_valid(poly_stroke):
		if cached_poly_strokes.is_empty():
			poly_stroke.hide()
		else:
			poly_stroke.show()
			var polygon_indices : Array = []
			var poly := Geometry2DUtil.get_polygon_indices(cached_poly_strokes, polygon_indices)
			poly_stroke.polygon = poly
			poly_stroke.polygons = polygon_indices
			_update_polygon_texture(poly_stroke, true)
	if is_instance_valid(polygon):
		if cached_clipped_polygons.is_empty():
			polygon.hide()
		else:
			polygon.show()
			var polygon_indices : Array = []
			var poly := Geometry2DUtil.get_polygon_indices(cached_clipped_polygons, polygon_indices)
			polygon.polygon = poly
			polygon.polygons = polygon_indices
			_update_polygon_texture()
	if is_instance_valid(collision_polygon):
		collision_polygon.polygon = polygon_points
	if is_instance_valid(collision_object):
		var existing = collision_object.get_children().filter(func(ch): return ch is CollisionPolygon2D)
		for idx in existing.size():
			if idx >= collision_polygons.size():
				existing[idx].hide()
				existing[idx].disabled = true
		for polygon_index in collision_polygons.size():
			if polygon_index >= existing.size():
				existing.append(_make_new_collision_polygon_2d())
			existing[polygon_index].polygon = collision_polygons[polygon_index]
			existing[polygon_index].show()
			existing[polygon_index].disabled = false

	if is_instance_valid(navigation_region):
		var navigation_poly = NavigationPolygon.new()
		for outline in navigation_polygons:
			navigation_poly.add_outline(outline)
		NavigationServer2D.bake_from_source_geometry_data(navigation_poly, NavigationMeshSourceGeometryData2D.new())
		navigation_region.navigation_polygon = navigation_poly


func _make_new_collision_polygon_2d() -> CollisionPolygon2D:
	var c_poly = CollisionPolygon2D.new()
	collision_object.add_child(c_poly, true)
	if collision_object.owner:
		c_poly.set_owner(collision_object.owner)
	if Engine.is_editor_hint() and lock_assigned_shapes:
		c_poly.set_meta("_edit_lock_", true)
	if collision_object not in get_children():
		c_poly.global_transform = global_transform
	return c_poly


func _make_new_line_2d() -> Line2D:
	var ln := Line2D.new()
	ln.name = "ExtraStroke"
	line.add_child(ln, true)
	ln.closed = true
	if line.owner:
		ln.set_owner(line.owner)
	if Engine.is_editor_hint() and lock_assigned_shapes:
		ln.set_meta("_edit_lock_", true)
	return ln


func _clip_path_to_local(clip_path : ScalableVectorShape2D) -> PackedVector2Array:
	var pts := clip_path.global_transform * clip_path.tessellate()
	return self.global_transform.affine_inverse() * pts


func get_center() -> Vector2:
	if shape_type != ShapeType.PATH:
		return offset
	return get_bounding_rect().get_center()


## Calculate and return the bounding rect in local space
func get_bounding_rect() -> Rect2:
	if not curve:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var points := self.tessellate()
	if points.size() < 1:
		# Cannot calculate a center for 0 points
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Geometry2DUtil.get_polygon_bounding_rect(points)


func has_point(global_pos : Vector2) -> bool:
	return get_bounding_rect().grow(
		stroke_width / 2.0 if is_instance_valid(line) or is_instance_valid(poly_stroke) else 0
	).has_point(to_local(global_pos))


func has_fine_point(global_pos : Vector2) -> bool:
	var poly_points := self.tessellate()
	if Geometry2D.is_point_in_polygon(to_local(global_pos), poly_points):
		return true
	for poly_points1 in cached_poly_strokes:
		if Geometry2D.is_point_in_polygon(to_local(global_pos), poly_points1):
			return true
	return false


func clipped_polygon_has_point(global_pos : Vector2) -> bool:
	if not has_point(global_pos) or not has_fine_point(global_pos):
		return false

	if cached_clipped_polygons.is_empty() and has_fine_point(global_pos):
		return true

	for poly_points1 in cached_poly_strokes:
		if Geometry2D.is_point_in_polygon(to_local(global_pos), poly_points1):
			return true

	for poly_points in cached_clipped_polygons:
		if Geometry2D.is_point_in_polygon(to_local(global_pos), poly_points):
			return true
	return false


func set_position_to_center() -> void:
	var c = get_center()
	position += c
	for i in range(curve.get_point_count()):
		curve.set_point_position(i, curve.get_point_position(i) - c)


func set_origin(global_pos : Vector2) -> void:
	var local_pos = to_local(global_pos)
	match shape_type:
		ShapeType.RECT, ShapeType.ELLIPSE:
			offset = offset - to_local(global_pos)
			global_position = global_pos
			if is_instance_valid(polygon) and polygon.texture is GradientTexture2D:
				polygon.texture_offset = -get_bounding_rect().position
		ShapeType.PATH, _:
			for i in range(curve.get_point_count()):
				curve.set_point_position(i, curve.get_point_position(i) - local_pos)
			global_position = global_pos
			if is_instance_valid(polygon) and polygon.texture is GradientTexture2D:
				polygon.texture_offset = -get_bounding_rect().position



func get_bounding_box() -> Array[Vector2]:
	var rect = get_bounding_rect().grow(
		stroke_width / 2.0 if is_instance_valid(line) or is_instance_valid(poly_stroke) else 0
	)
	return [
		to_global(rect.position),
		to_global(Vector2(rect.position.x + rect.size.x, rect.position.y)),
		to_global(rect.position + rect.size),
		to_global(Vector2(rect.position.x, rect.position.y  + rect.size.y)),
		to_global(rect.position)
	]


func get_poly_points() -> Array:
	return Array(self.tessellate()).map(to_global)


func get_farthest_point(from_local_pos := Vector2.ZERO) -> Vector2:
	var farthest_point = from_local_pos
	for p in self.tessellate():
		if p.distance_to(from_local_pos) > farthest_point.distance_to(from_local_pos):
			farthest_point = p
	return farthest_point


func is_curve_closed() -> bool:
	var n = curve.point_count
	return n > 2 and curve.get_point_position(0).distance_to(curve.get_point_position(n - 1)) < 0.001


func get_curve_handles() -> Array:
	if shape_type == ShapeType.RECT or shape_type == ShapeType.ELLIPSE:
		var size_handle_pos := (size * 0.5).rotated(spin) + offset
		var top_left := (-size * 0.5).rotated(spin) + offset
		var rx_handle := ((-size * 0.5) + Vector2(rx, 0)).rotated(spin) + offset
		var ry_handle := ((-size * 0.5) + Vector2(0, ry)).rotated(spin) + offset
		return [{
			"top_left_pos": to_global(top_left),
			"point_position": to_global(size_handle_pos),
			"mirrored": true,
			"in": rx_handle,
			"out": ry_handle,
			"in_position": to_global(rx_handle),
			"out_position": to_global(ry_handle),
			"is_closed": "",
		}]


	var n = curve.point_count
	var is_closed := is_curve_closed()
	var result := []
	for i in range(n):
		var p = curve.get_point_position(i)
		var c_i = curve.get_point_in(i)
		var c_o = curve.get_point_out(i)
		if i == 0 and is_closed:
			c_i = curve.get_point_in(n - 1)
		elif i == n - 1 and is_closed:
			continue
		result.append({
			'point_position': to_global(p),
			'in': c_i,
			'out': c_o,
			'mirrored': c_i.length() and c_i.distance_to(-c_o) < 0.01,
			'in_position': to_global(p + c_i),
			'out_position': to_global(p + c_o),
			'is_closed': (" ∞ " + str(n - 1) if i == 0 and is_closed else "")
		})
	return result


func get_gradient_handles() -> Dictionary:
	if not (
		is_instance_valid(polygon) and polygon.texture is GradientTexture2D
	):
		return {}
	var gradient_tex : GradientTexture2D = polygon.texture
	var box := get_bounding_rect()
	var stop_colors = Array(
		gradient_tex.gradient.colors if gradient_tex.gradient.colors else [
			Color.WHITE, Color.BLACK
		]
	).map(func(gc): return gc * polygon.color)
	var stop_positions = Array(gradient_tex.gradient.offsets).map(
		func(offs): return (gradient_tex.fill_to - gradient_tex.fill_from) * offs
	).map(func(offs_p): return gradient_tex.fill_from + offs_p
	).map(func(offs_p1): return to_global((offs_p1 * box.size) + box.position))

	var result := {
		"fill_from": gradient_tex.fill_from,
		"fill_to": gradient_tex.fill_to,
		"fill_from_pos": to_global((gradient_tex.fill_from * box.size) + box.position),
		"fill_to_pos":  to_global((gradient_tex.fill_to * box.size) + box.position),
		"start_color": stop_colors[0] * polygon.color,
		"end_color": stop_colors[stop_colors.size() - 1] * polygon.color,
		"stop_positions": stop_positions,
		"stop_colors": stop_colors
	}

	return result


func flip_points(flip_dir := Vector2(-1, 1)) -> void:
	if shape_type == ShapeType.PATH:
		curve.set_block_signals(true)
		arc_list.set_block_signals(true)
		for i in curve.point_count:
			curve.set_point_position(i, curve.get_point_position(i) * flip_dir)
			curve.set_point_in(i, curve.get_point_in(i) * flip_dir)
			curve.set_point_out(i, curve.get_point_out(i) * flip_dir)
		for i in arc_list.arcs.size():
			arc_list.arcs[i].sweep_flag = not arc_list.arcs[i].sweep_flag
		arc_list.set_block_signals(false)
		curve.set_block_signals(false)
		curve.emit_changed()
		arc_list.emit_changed()
	else:
		spin = -spin


func translate_points_by(global_vector : Vector2) -> void:
	var delta := global_vector.rotated(-global_rotation) / global_scale
	if shape_type == ShapeType.PATH:
		curve.set_block_signals(true)
		for idx in curve.point_count:
			curve.set_point_position(idx, curve.get_point_position(idx) + delta)
		curve.set_block_signals(false)
		curve.emit_changed()
	else:
		offset += delta


func scale_points_by(from_global_vector : Vector2, to_global_vector : Vector2, around_center := false) -> void:
	var local_from := to_local(from_global_vector)
	var local_to := to_local(to_global_vector)
	var origin := get_center() if around_center else Vector2.ZERO
	var s := origin.distance_to(local_to) / origin.distance_to(local_from)
	if shape_type == ShapeType.PATH:
		curve.set_block_signals(true)
		for idx in curve.point_count:
			var p := curve.get_point_position(idx)
			var p1 := (p - origin) * s + origin
			var cp_in_abs := curve.get_point_in(idx) + p
			var cp_out_abs := curve.get_point_out(idx) + p
			var cp_in_abs_1 := (cp_in_abs - origin) * s + origin
			var cp_out_abs_1 := (cp_out_abs - origin) * s + origin
			curve.set_point_position(idx, p1)
			curve.set_point_in(idx, cp_in_abs_1 - p1)
			curve.set_point_out(idx, cp_out_abs_1 - p1)

		curve.set_block_signals(false)
		curve.emit_changed()
	else:
		size *= s


func rotate_points_by(angle : float, rotation_origin := Vector2.ZERO) -> void:
	if shape_type != ShapeType.PATH:
		spin += angle
		return
	var transform := Transform2D.IDENTITY.rotated(-angle)
	curve.set_block_signals(true)
	for idx in curve.point_count:
		var p := curve.get_point_position(idx)
		var p1 := (p - rotation_origin) * transform + rotation_origin
		var cp_in_abs := curve.get_point_in(idx) + p
		var cp_out_abs := curve.get_point_out(idx) + p
		var cp_in_abs_1 := (cp_in_abs - rotation_origin) * transform + rotation_origin
		var cp_out_abs_1 := (cp_out_abs - rotation_origin) * transform + rotation_origin
		curve.set_point_position(idx, p1)
		curve.set_point_in(idx, cp_in_abs_1 - p1)
		curve.set_point_out(idx, cp_out_abs_1 - p1)
	curve.set_block_signals(false)
	curve.emit_changed()


func set_global_curve_point_position(global_pos : Vector2, point_idx : int, snapped : bool,
			snap : float) -> void:
	if curve.point_count > point_idx:
		if snapped:
			global_pos = snapped(global_pos, Vector2.ONE * snap)
		curve.set_point_position(point_idx, to_local(global_pos))


func set_global_curve_cp_in_position(global_pos : Vector2, point_idx : int, snapped : bool,
			snap : float) -> void:
	if curve.point_count > point_idx:
		if snapped:
			global_pos = snapped(global_pos, Vector2.ONE * snap)
		curve.set_point_in(point_idx, to_local(global_pos) - curve.get_point_position(point_idx))


func set_global_curve_cp_out_position(global_pos : Vector2, point_idx : int, snapped : bool,
			snap : float) -> void:
	if curve.point_count > point_idx:
		if snapped:
			global_pos = snapped(global_pos, Vector2.ONE * snap)
		curve.set_point_out(point_idx, to_local(global_pos) - curve.get_point_position(point_idx))


func replace_curve_points(curve_in : Curve2D) -> void:
	curve.clear_points()
	for i in range(curve_in.point_count):
		curve.add_point(curve_in.get_point_position(i),
				curve_in.get_point_in(i), curve_in.get_point_out(i))


func add_arc(segment_p1_idx : int) -> void:
	var seg := _get_curve_segment(segment_p1_idx)
	var r := seg.get_point_position(0).distance_to(seg.get_point_position(1)) * 0.5
	arc_list.add_arc(ScalableArc.new(segment_p1_idx, Vector2.ONE * r, 0.0))


func _get_curve_segment(segment_p1_idx : int) -> Curve2D:
	var curve_segment := Curve2D.new()
	curve_segment.add_point(
		curve.get_point_position(segment_p1_idx),
		Vector2.ZERO,
		curve.get_point_out(segment_p1_idx)
	)
	var segment_p2_idx = (0 if segment_p1_idx == curve.point_count - 1
			else segment_p1_idx + 1)
	curve_segment.add_point(
		curve.get_point_position(segment_p2_idx),
		curve.get_point_in(segment_p2_idx)
	)
	return curve_segment


func is_arc_start(p_idx) -> bool:
	return  arc_list.get_arc_for_point(p_idx) != null


func _get_closest_point_on_curve_segment(p : Vector2, segment_p1_idx : int) -> Vector2:
	var arc := arc_list.get_arc_for_point(segment_p1_idx)
	var seg := _get_curve_segment(segment_p1_idx)
	var poly_points := (
			tessellate_arc_segment(seg.get_point_position(0), arc.radius, arc.rotation_deg,
				arc.large_arc_flag, arc.sweep_flag, seg.get_point_position(1))
		if arc else
			seg.tessellate(max_stages, tolerance_degrees)
	)
	var closest_result := Vector2.INF
	for i in range(1, poly_points.size()):
		var p_a := poly_points[i - 1]
		var p_b := poly_points[i]
		var c_p := Geometry2D.get_closest_point_to_segment(p, p_a, p_b)
		if p.distance_to(c_p) < p.distance_to(closest_result):
			closest_result = c_p
	return closest_result


func get_closest_point_on_curve(global_pos : Vector2) -> ClosestPointOnCurveMeta:
	var p := to_local(global_pos)
	if curve.point_count < 2:
		return ClosestPointOnCurveMeta.new(1, global_pos, p)

	var closest_result := Vector2.INF
	var before_segment := 1
	for i in range(curve.point_count):
		var c_p := _get_closest_point_on_curve_segment(p, i)
		if p.distance_to(c_p) < p.distance_to(closest_result):
			closest_result = c_p
			before_segment = i + 1
	return ClosestPointOnCurveMeta.new(before_segment, to_global(closest_result), closest_result)


# Adapted from the GodSVG repository to draw arc in stead of determine bounding box.
# https://github.com/MewPurPur/GodSVG/blob/53168a8cf74739fe828f488901eada02d5d97b69/src/data_classes/ElementPath.gd#L118
func tessellate_arc_segment(start : Vector2, arc_radius : Vector2, arc_rotation_deg : float,
						large_arc_flag : bool, sweep_flag : bool, end : Vector2) -> PackedVector2Array:

	if start == end or arc_radius.x == 0 or arc_radius.y == 0:
		return [start, end]

	var r := arc_radius.abs()
	# Obtain center parametrization.
	var rot := deg_to_rad(arc_rotation_deg)
	var cosine := cos(rot)
	var sine := sin(rot)
	var half := (start - end) / 2
	var x1 := half.x * cosine + half.y * sine
	var y1 := -half.x * sine + half.y * cosine
	var r2 := Vector2(r.x * r.x, r.y * r.y)
	var x12 := x1 * x1
	var y12 := y1 * y1
	var cr := x12 / r2.x + y12 / r2.y
	if cr > 1:
		cr = sqrt(cr)
		r *= cr
		r2 = Vector2(r.x * r.x, r.y * r.y)

	var dq := r2.x * y12 + r2.y * x12
	var pq := (r2.x * r2.y - dq) / dq
	var sc := sqrt(maxf(0, pq))
	if large_arc_flag == sweep_flag:
		sc = -sc

	var ct := Vector2(r.x * sc * y1 / r.y, -r.y * sc * x1 / r.x)
	var c := Vector2(ct.x * cosine - ct.y * sine,
			ct.x * sine + ct.y * cosine) + start.lerp(end, 0.5)
	var tv := Vector2(x1 - ct.x, y1 - ct.y) / r
	var theta1 := tv.angle()
	var delta_theta := fposmod(tv.angle_to(
			Vector2(-x1 - ct.x, -y1 - ct.y) / r), TAU)
	if not sweep_flag:
		theta1 += delta_theta
		delta_theta = TAU - delta_theta
	theta1 = fposmod(theta1, TAU)

	var step := deg_to_rad(1.0 if tolerance_degrees < 1.0 else tolerance_degrees)
	var angle := theta1 if sweep_flag else theta1 + delta_theta
	var init_pnt := Vector2(c.x + r.x * cos(angle) * cosine - r.y * sin(angle) * sine,
				c.y + r.x * cos(angle) * sine + r.y * sin(angle) * cosine)
	var points : PackedVector2Array = []
	while (sweep_flag and angle < theta1 + delta_theta) or (not sweep_flag and angle > theta1):
		var pnt := Vector2(c.x + r.x * cos(angle) * cosine - r.y * sin(angle) * sine,
				c.y + r.x * cos(angle) * sine + r.y * sin(angle) * cosine)
		points.append(pnt)
		if sweep_flag:
			angle += step
		else:
			angle -= step
	if points[points.size() - 1] != end:
		if points[points.size() - 1].distance_to(end) < 0.01:
			points[points.size() - 1] = end
		else:
			points.append(end)
	return points


## Convert an existing [Curve2D] instance to a (rounded) rectangle.
## [param curve] is passed by reference so the curve's [signal Resource.changed]
## signal is emitted.
static func set_rect_points(curve : Curve2D, width : float, height : float, rx := 0.0, ry := 0.0,
		offset := Vector2.ZERO, rotation := 0.0) -> void:
	curve.set_block_signals(true)
	curve.clear_points()
	var top_left := Vector2(-width, -height) * 0.5
	var top_right := Vector2(width, -height) * 0.5
	var bottom_right := Vector2(width, height) * 0.5
	var bottom_left := Vector2(-width, height) * 0.5
	if rx == 0 and ry == 0:
		curve.add_point(top_left.rotated(rotation) + offset)
		curve.add_point(top_right.rotated(rotation) + offset)
		curve.add_point(bottom_right.rotated(rotation) + offset)
		curve.add_point(bottom_left.rotated(rotation) + offset)
		curve.add_point(top_left.rotated(rotation) + offset)
	else:
		curve.add_point(
			(top_left + Vector2(width - rx, 0)).rotated(rotation) + offset,
			Vector2.ZERO,
			Vector2(rx * R_TO_CP, 0).rotated(rotation)
		)
		curve.add_point(
			(top_left + Vector2(width, ry)).rotated(rotation) + offset,
			Vector2(0, -ry * R_TO_CP).rotated(rotation)
		)
		curve.add_point(
			(top_left + Vector2(width, height - ry)).rotated(rotation) + offset,
			Vector2.ZERO,
			Vector2(0, ry * R_TO_CP).rotated(rotation)
		)
		curve.add_point(
			(top_left + Vector2(width - rx, height)).rotated(rotation) + offset,
			Vector2(rx * R_TO_CP, 0).rotated(rotation)
		)
		curve.add_point(
			(top_left + Vector2(rx, height)).rotated(rotation) + offset,
			Vector2.ZERO,
			Vector2(-rx * R_TO_CP, 0).rotated(rotation)
		)
		curve.add_point(
			(top_left + Vector2(0, height - ry)).rotated(rotation) + offset,
			Vector2(0, ry * R_TO_CP).rotated(rotation)
		)
		curve.add_point(
			(top_left + Vector2(0, ry)).rotated(rotation) + offset,
			Vector2.ZERO,
			Vector2(0, -ry *  R_TO_CP).rotated(rotation)
		)
		curve.add_point(
			(top_left + Vector2(rx, 0)).rotated(rotation) + offset,
			Vector2(-rx * R_TO_CP, 0).rotated(rotation)
		)
		curve.add_point(
			(top_left + Vector2(width - rx, 0)).rotated(rotation) + offset,
			Vector2.ZERO,
			Vector2(rx * R_TO_CP, 0).rotated(rotation)
		)

	curve.set_block_signals(false)
	curve.changed.emit()


## Convert an existing [Curve2D] instance to an ellipse.
## [param curve] is passed by reference so the curve's [signal Resource.changed]
## signal is emitted.
static func set_ellipse_points(curve : Curve2D, size: Vector2, offset := Vector2.ZERO, rotation := 0.0):
	curve.set_block_signals(true)
	curve.clear_points()
	curve.add_point(
		offset + Vector2(size.x * 0.5, 0).rotated(rotation),
		Vector2.ZERO,
		Vector2(0, size.y * 0.5 * R_TO_CP).rotated(rotation)
	)
	curve.add_point(
		offset + Vector2(0, size.y * 0.5).rotated(rotation),
		Vector2(size.x * 0.5 * R_TO_CP, 0).rotated(rotation),
		Vector2(-size.x * 0.5 * R_TO_CP, 0).rotated(rotation)
	)
	curve.add_point(
		offset + Vector2(-size.x * 0.5, 0).rotated(rotation),
		Vector2(0, size.y * 0.5 * R_TO_CP).rotated(rotation),
		Vector2(0, -size.y * 0.5 * R_TO_CP).rotated(rotation)
	)
	curve.add_point(
		offset + Vector2(0, -size.y * 0.5).rotated(rotation),
		Vector2(-size.x * 0.5 * R_TO_CP, 0).rotated(rotation),
		Vector2(size.x * 0.5 * R_TO_CP, 0).rotated(rotation)
	)
	curve.add_point(
		offset + Vector2(size.x * 0.5, 0).rotated(rotation),
		Vector2(0, -size.y * 0.5 * R_TO_CP).rotated(rotation)
	)
	curve.set_block_signals(false)
	curve.changed.emit()

