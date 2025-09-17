@tool
extends Control

# Fraction of a radius for a bezier control point
const R_TO_CP = 0.5523
const PLC_EXP = "__PLC_EXP__"

const SVG_ROOT_META_NAME := "svg_root"
const SVG_STYLE_META_NAME := "svg_style"

const PAINT_ORDER_MAP := {
	"normal": ['add_fill_to_path', 'add_stroke_to_path', 'add_collision_to_path'],
	"fill stroke markers": ['add_fill_to_path', 'add_stroke_to_path', 'add_collision_to_path'],
	"stroke fill markers": ['add_stroke_to_path', 'add_fill_to_path', 'add_collision_to_path'],
	"fill markers stroke": ['add_fill_to_path', 'add_collision_to_path', 'add_stroke_to_path'],
	"markers fill stroke": ['add_collision_to_path', 'add_fill_to_path', 'add_stroke_to_path'],
	"stroke markers fill": ['add_stroke_to_path', 'add_collision_to_path', 'add_fill_to_path'],
	"markers stroke fill": ['add_collision_to_path', 'add_stroke_to_path', 'add_fill_to_path']
}
const STROKE_CAP_MAP := {
	"butt": Line2D.LineCapMode.LINE_CAP_NONE,
	"round": Line2D.LineCapMode.LINE_CAP_ROUND,
	"square": Line2D.LineCapMode.LINE_CAP_BOX
}
const STROKE_JOINT_MAP := {
	"miter": Line2D.LineJointMode.LINE_JOINT_SHARP,
	"miter-clip": Line2D.LineJointMode.LINE_JOINT_SHARP,
	"round": Line2D.LineJointMode.LINE_JOINT_ROUND,
	"bevel": Line2D.LineJointMode.LINE_JOINT_BEVEL,
	"arc": Line2D.LineJointMode.LINE_JOINT_SHARP
}

enum LogLevel { DEBUG, INFO, WARN, ERROR }
var error_label_settings : LabelSettings = null
var warning_label_settings : LabelSettings = null
var info_label_settings : LabelSettings = null
var debug_label_settings : LabelSettings = null

## Settings
var collision_object_type := ScalableVectorShape2D.CollisionObjectType.NONE
var import_as_svs := true
var lock_shapes := true
var antialiased_shapes := false
var import_stroke_as_line_2d := true
var import_file_dialog : EditorFileDialog = null
var warning_dialog : AcceptDialog = null
var undo_redo : EditorUndoRedoManager = null
var LinkButtonScene : PackedScene = null

func _enter_tree() -> void:
	error_label_settings = preload("res://addons/curved_lines_2d/error_label_settings.tres")
	warning_label_settings = preload("res://addons/curved_lines_2d/warn_label_settings.tres")
	info_label_settings = preload("res://addons/curved_lines_2d/info_label_settings.tres")
	debug_label_settings = preload("res://addons/curved_lines_2d/debug_label_settings.tres")
	LinkButtonScene = preload("res://addons/curved_lines_2d/link_button_with_copy_hint.tscn")
	%LogScrollContainer.get_v_scroll_bar().connect("changed", func(): %LogScrollContainer.scroll_vertical = %LogScrollContainer.get_v_scroll_bar().max_value )
	import_file_dialog = EditorFileDialog.new()
	import_file_dialog.add_filter("*.svg", "SVG image")
	import_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	import_file_dialog.file_selected.connect(_load_svg)
	EditorInterface.get_base_control().add_child(import_file_dialog)
	undo_redo = EditorInterface.get_editor_undo_redo()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not typeof(data) == TYPE_DICTIONARY and "type" in data and data["type"] == "files":
		return false
	for file : String in data["files"]:
		if file.ends_with(".svg"):
			return true
	return false


func log_message(msg : String, log_level : LogLevel = LogLevel.INFO) -> void:
	var lbl := Label.new()
	match log_level:
		LogLevel.ERROR:
			warning_dialog.dialog_text = msg
			warning_dialog.popup_centered()
			lbl.label_settings = error_label_settings
		LogLevel.WARN:
			lbl.label_settings = warning_label_settings
		LogLevel.DEBUG:
			lbl.label_settings = debug_label_settings
		LogLevel.INFO,_:
			lbl.label_settings = info_label_settings
	lbl.text = msg

	%ImportLogContainer.add_child(lbl)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		_load_svg(data["files"][0])


func _get_viewport_center() -> Vector2:
	var tr := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var og := tr.get_origin()
	var sz := Vector2(EditorInterface.get_editor_viewport_2d().size)
	return (sz / 2) / tr.get_scale() - og / tr.get_scale()


func _load_svg(file_path : String) -> void:
	for child in %ImportLogContainer.get_children():
		child.queue_free()
	var xml_parser = XMLParser.new()
	var scene_root := EditorInterface.get_edited_scene_root()
	var selected_nodes := EditorInterface.get_selection().get_selected_nodes()
	var parent_node := scene_root if selected_nodes.is_empty() else selected_nodes[0]
	if not scene_root is Node:
		log_message("ERROR: Can only import into an opened scene", LogLevel.ERROR)
		return
	if xml_parser.open(file_path) != OK:
		log_message("ERROR: Failed to open %s for reading" % file_path, LogLevel.ERROR)
		return

	log_message("Importing SVG file: %s" % file_path, LogLevel.INFO)
	var svg_root := Node2D.new()
	svg_root.name = file_path.get_file().replace(".svg", "").to_pascal_case()
	undo_redo.create_action("Import SVG file as Nodes: %s" % svg_root.name)
	svg_root.set_meta(SVG_ROOT_META_NAME, true)

	_managed_add_child_and_set_owner(parent_node, svg_root, scene_root)

	var current_node := svg_root
	var svg_gradients : Array[Dictionary] = []

	var svg_xml_node : SVGXMLElement = parse_svg_xml_file(xml_parser)
	process_svg_xml_tree(svg_xml_node, scene_root, svg_root, current_node, svg_gradients)
	undo_redo.commit_action(false)


	if not import_as_svs:
		await RenderingServer.frame_post_draw
		Line2DGeneratorInspectorPlugin._copy_baked_node(svg_root, parent_node, scene_root)
		parent_node.remove_child(svg_root)


	log_message("Import finished.\n\nThe SVG importer is still incrementally improving (slowly).")
	var link_button = LinkButtonScene.instantiate()
	link_button.text = "Click here to report issues or improvement requests on github"
	link_button.uri = "https://github.com/Teaching-myself-Godot/ez-curved-lines-2d/issues"
	%ImportLogContainer.add_child(link_button)

	var selection_target = (
			svg_root.find_children("*", "ScalableVectorShape2D")
				.filter(func(n : CanvasItem): return n.is_visible_in_tree()).pop_front()
	)
	if not is_instance_valid(selection_target):
		selection_target = svg_root
	EditorInterface.call_deferred('edit_node', selection_target)
	await get_tree().create_timer(0.0167).timeout
	EditorInterface.get_editor_viewport_2d().get_parent().grab_focus()
	var key_ev := InputEventKey.new()
	key_ev.keycode = KEY_F
	key_ev.pressed = true
	Input.parse_input_event(key_ev)

func parse_svg_xml_file(xml_parser : XMLParser) -> SVGXMLElement:
	var svg_xml_node : SVGXMLElement = null
	while xml_parser.read() == OK:
		if not xml_parser.get_node_type() in [XMLParser.NODE_ELEMENT, XMLParser.NODE_ELEMENT_END]:
			continue
		if xml_parser.get_node_type() == XMLParser.NODE_ELEMENT and xml_parser.is_empty() and xml_parser.get_node_name() in ["defs", "g", "clipPath"]:
			continue
		if xml_parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if svg_xml_node.parent:
				svg_xml_node = svg_xml_node.parent
		else:
			var new_svg_xml_node := SVGXMLElement.new(xml_parser, svg_xml_node)
			if svg_xml_node:
				svg_xml_node.add_child(new_svg_xml_node)
			if not xml_parser.is_empty():
				svg_xml_node = new_svg_xml_node
	return svg_xml_node

func process_svg_xml_tree(xml_data : SVGXMLElement, scene_root : Node, svg_root :
			Node2D, current_node : Node2D, svg_gradients : Array[Dictionary]) -> void:

	if xml_data.name == "use":
		var href = xml_data.get_named_attribute_value_safe("xlink:href")
		if href.is_empty():
			href = xml_data.get_named_attribute_value_safe("href")
		var reuse_xml_node = xml_data.find_by_id(href.replace("#", ""))
		var style = xml_data.get_svg_style(log_message)
		style.merge(reuse_xml_node.get_merged_styles(log_message))
		var preserve_id := xml_data.get_named_attribute_value_safe("id")
		xml_data.attributes.erase("xlink:href")
		xml_data.attributes.merge(reuse_xml_node.attributes)
		xml_data.attributes["id"] = preserve_id
		xml_data.attributes["style"] = "; ".join(style.keys().map(func(k): return k + ": " + style[k]))
		if preserve_id.is_empty():
			xml_data.attributes.erase("id")
		xml_data.name = reuse_xml_node.name

	match xml_data.name:
		"svg":
			if xml_data.has_attribute("viewBox") and xml_data.has_attribute("width") and xml_data.has_attribute("height"):
				var view_box = xml_data.get_named_attribute_value("viewBox").split_floats(" ")
				var width := float(xml_data.get_named_attribute_value("width"))
				var height := float(xml_data.get_named_attribute_value("height"))
				svg_root.scale.x = width / view_box[2]
				svg_root.scale.y = height / view_box[3]
				if xml_data.get_named_attribute_value("width").ends_with("mm"): # unit conversion to pixel
					log_message("⚠️ Units for this image are millimeters (mm), image scale set to 3.78")
					svg_root.scale *= 3.78
				elif xml_data.get_named_attribute_value("width").ends_with("cm"):
					log_message("⚠️ Units for this image are centimeters (cm), image scale set to 37.8")
					svg_root.scale *= 37.8
			if xml_data.has_attribute("style"):
				current_node.set_meta(SVG_STYLE_META_NAME, xml_data.get_merged_styles(log_message))
		"g":
			current_node = process_group(xml_data, current_node, scene_root)
		"clipPath", "defs":
			current_node = process_group(xml_data, current_node, scene_root, xml_data.name)
			current_node.hide()
		"rect":
			process_svg_rectangle(xml_data, current_node, scene_root, svg_gradients)
		"image":
			process_svg_image(xml_data, current_node, scene_root, svg_gradients)
		"polygon":
			process_svg_polygon(xml_data, current_node, scene_root, true, svg_gradients)
		"polyline":
			process_svg_polygon(xml_data, current_node, scene_root, false, svg_gradients)
		"path":
			process_svg_path(xml_data, current_node, scene_root, svg_gradients)
		"circle":
			process_svg_circle(xml_data, current_node, scene_root, svg_gradients)
		"ellipse":
			process_svg_ellipse(xml_data, current_node, scene_root, svg_gradients)
		"linearGradient", "radialGradient":
			svg_gradients.append(parse_gradient(xml_data))
		"stop":
			pass
		_: log_message("⚠️ Skipping  unsupported node: <%s>" % xml_data.name, LogLevel.DEBUG)

	var defs := xml_data.children.filter(func(ch): return ch.name == "defs")
	var clip_paths := xml_data.children.filter(func(ch): return ch.name == "clipPath")
	var remainder := xml_data.children.filter(func(ch): return ch.name != "defs" and ch.name != "clipPath")
	for ch in defs + clip_paths + remainder:
		process_svg_xml_tree(ch, scene_root, svg_root, current_node, svg_gradients)


func get_gradient_by_href(href : String, gradients : Array[Dictionary]) -> Dictionary:
	var idx := gradients.find_custom(func(x): return "id" in x and "#" + x["id"] == href)
	if idx < 0:
		return {}
	return gradients[idx]


func parse_gradient(gradient_xml : SVGXMLElement) -> Dictionary:
	var new_gradient = {
		'is_radial': gradient_xml.get_node_name() == "radialGradient"
	}
	for x in gradient_xml.attributes:
		new_gradient[x] = gradient_xml.attributes[x]
	if not gradient_xml.is_empty():
		new_gradient["stops"] = []
		for element in gradient_xml.children:
			if element.get_node_name() == "stop":
				new_gradient["stops"].append({
					"style": element.get_merged_styles(log_message),
					"offset": float(element.get_named_attribute_value_safe("offset")),
					"id": element.get_named_attribute_value_safe("id")
				})

	return new_gradient


func process_group(element:SVGXMLElement, current_node : Node2D, scene_root : Node, alt_name := "Group") -> Node2D:
	var new_group = Node2D.new()
	new_group.name = element.get_named_attribute_value("id") if element.has_attribute("id") else alt_name
	new_group.transform = get_svg_transform(element)
	var style := element.get_merged_styles(log_message)
	new_group.set_meta(SVG_STYLE_META_NAME, style)

	if style.has("display") and style['display'] == "none":
		new_group.visible = false
	_managed_add_child_and_set_owner(current_node, new_group, scene_root)
	return new_group


func process_svg_circle(element:SVGXMLElement, current_node : Node2D, scene_root : Node,
		gradients : Array[Dictionary]) -> void:
	var cx = float(element.get_named_attribute_value("cx"))
	var cy = float(element.get_named_attribute_value("cy"))
	var r = float(element.get_named_attribute_value("r"))
	var path_name = element.get_named_attribute_value("id") if element.has_attribute("id") else "Circle"
	create_path_from_ellipse(element, path_name, r, r, Vector2(cx, cy), current_node, scene_root, gradients)


func process_svg_ellipse(element:SVGXMLElement, current_node : Node2D, scene_root : Node,
		gradients : Array[Dictionary]) -> void:
	var cx = float(element.get_named_attribute_value("cx"))
	var cy = float(element.get_named_attribute_value("cy"))
	var rx = float(element.get_named_attribute_value("rx"))
	var ry = float(element.get_named_attribute_value("ry"))
	var path_name = element.get_named_attribute_value("id") if element.has_attribute("id") else "Ellipse"
	create_path_from_ellipse(element, path_name, rx, ry, Vector2(cx, cy), current_node, scene_root, gradients)


func create_path_from_ellipse(element:SVGXMLElement, path_name : String, rx : float, ry: float,
		pos : Vector2, current_node : Node2D, scene_root : Node,
		gradients : Array[Dictionary]) -> void:
	var new_ellipse := ScalableVectorShape2D.new()
	new_ellipse.shape_type = ScalableVectorShape2D.ShapeType.ELLIPSE
	new_ellipse.size = Vector2(rx * 2, ry * 2)
	new_ellipse.position = pos
	new_ellipse.name = path_name
	_post_process_shape(new_ellipse, current_node, get_svg_transform(element),
			element.get_merged_styles(log_message), scene_root, gradients)

func process_svg_image(element:SVGXMLElement, current_node : Node2D, scene_root : Node,
		gradients : Array[Dictionary]) -> void:
	var x = float(element.get_named_attribute_value("x")) if element.has_attribute("x") else 0.0
	var y = float(element.get_named_attribute_value("y")) if element.has_attribute("y") else 0.0
	var width = float(element.get_named_attribute_value("width"))
	var height = float(element.get_named_attribute_value("height"))
	var new_image_rect := ScalableVectorShape2D.new()
	new_image_rect.shape_type = ScalableVectorShape2D.ShapeType.RECT
	new_image_rect.size = Vector2(width, height)
	new_image_rect.position = Vector2(x, y) + new_image_rect.size * 0.5
	new_image_rect.name = element.get_named_attribute_value("id") if element.has_attribute("id") else "Image"
	var image_data : String = (
		element.get_named_attribute_value("xlink:href")
			if element.has_attribute("xlink:href") else
		element.get_named_attribute_value_safe("href")
	)
	var image_texture : ImageTexture = null
	if image_data.begins_with("data:image") and image_data.contains("base64"):
		var parts_a := image_data.split(",")
		var parts_b := parts_a[0].split("/")
		var format := parts_b[1].replace(";", "").replace("base64", "").strip_edges()
		var base_64_data := parts_a[1].strip_edges()
		var unmarshalled := Marshalls.base64_to_raw(base_64_data)
		var image := Image.new()
		image.call("load_%s_from_buffer" % format.to_lower(), unmarshalled)
		image_texture = ImageTexture.create_from_image(image)
		log_message("Parsed image format: %s" % format, LogLevel.DEBUG)
	else:
		log_message("⚠️ Only base64 encoded embedded images are supported", LogLevel.WARN)

	_post_process_shape(new_image_rect, current_node, get_svg_transform(element),
			element.get_merged_styles(log_message), scene_root, gradients, false, image_texture)


func process_svg_rectangle(element:SVGXMLElement, current_node : Node2D, scene_root : Node,
		gradients : Array[Dictionary]) -> void:
	var x = float(element.get_named_attribute_value("x"))
	var y = float(element.get_named_attribute_value("y"))
	var rx = float(element.get_named_attribute_value("rx")) if element.has_attribute("rx") else 0
	var ry = float(element.get_named_attribute_value("ry")) if element.has_attribute("ry") else 0
	if rx == 0 and ry != 0:
		rx = ry
	if ry == 0 and rx != 0:
		ry = rx
	var width = float(element.get_named_attribute_value("width"))
	var height = float(element.get_named_attribute_value("height"))
	var new_rect := ScalableVectorShape2D.new()
	new_rect.shape_type = ScalableVectorShape2D.ShapeType.RECT
	new_rect.size = Vector2(width, height)
	new_rect.position = Vector2(x, y) + new_rect.size * 0.5
	new_rect.rx = rx
	new_rect.ry = ry
	new_rect.name = element.get_named_attribute_value("id") if element.has_attribute("id") else "Rectangle"
	_post_process_shape(new_rect, current_node, get_svg_transform(element),
			element.get_merged_styles(log_message), scene_root, gradients)


func process_svg_polygon(element:SVGXMLElement, current_node : Node2D, scene_root : Node, is_closed : bool,
		gradients : Array[Dictionary]) -> void:
	var points_split = element.get_named_attribute_value("points").split(" ", false)
	var curve = Curve2D.new()
	for p in points_split:
		var values = p.split_floats(",", false)
		curve.add_point(Vector2(values[0], values[1]))
	var path_name = (element.get_named_attribute_value("id") if element.has_attribute("id") else
			"Polygon" if is_closed else
			"Polyline"
	)
	create_path2d(path_name, current_node, curve, [], get_svg_transform(element),
			element.get_merged_styles(log_message), scene_root, gradients, is_closed)


func process_svg_path(element:SVGXMLElement, current_node : Node2D, scene_root : Node,
		gradients : Array[Dictionary]) -> void:

	# FIXME: implement better parsing here
	var str_path = parse_attribute_string(
				element.get_named_attribute_value("d")).replacen(",", " ")

	for symbol in ["m", "M", "v", "V", "h", "H", "l", "L", "c", "C", "s", "S", "a", "A", "q", "Q", "t", "T", "z", "Z"]:
		str_path = str_path.replace(symbol, " " + symbol + " ")

	# FIXME: this bit is especially problematic
	str_path = str_path.replace("e-", PLC_EXP)
	str_path = str_path.replace("-", " -")
	str_path = str_path.replace(PLC_EXP, "e-")
	var str_path_array = str_path.split(" ", false)
	var string_arrays = []
	var string_array_top : PackedStringArray
	for a in str_path_array:
		if a == "m" or a == "M":
			if string_array_top.size() > 0:
				string_arrays.append(string_array_top.duplicate())
				string_array_top.resize(0)
		string_array_top.append(a)
	string_arrays.append(string_array_top)

	if string_arrays.size() > 1:
		log_message("⚠️ Support for the m/M (move to) command is limited to cut-outs in svg paths")
	var string_array_count = 0
	var cursor = Vector2.ZERO
	var main_shape : ScalableVectorShape2D = null
	var new_clip_paths : Array[ScalableVectorShape2D] = []
	for string_array in string_arrays:
		var curve = Curve2D.new()
		var arcs : Array[ScalableArc] = []
		string_array_count += 1
		var cursor_start := Vector2.ZERO
		for i in string_array.size():
			var cursor_start_is_set := false
			match string_array[i]:
				"m":
					while string_array.size() > i + 2 and string_array[i+1].is_valid_float():
						cursor += Vector2(float(string_array[i+1]), float(string_array[i+2]))
						curve.add_point(cursor)
						i += 2
						if not cursor_start_is_set:
							cursor_start_is_set = true
							cursor_start = cursor
				"M":
					while string_array.size() > i + 2 and string_array[i+1].is_valid_float():
						cursor = Vector2(float(string_array[i+1]), float(string_array[i+2]))
						curve.add_point(cursor)
						i += 2
						if not cursor_start_is_set:
							cursor_start_is_set = true
							cursor_start = cursor
				"v":
					while string_array[i+1].is_valid_float():
						cursor.y += float(string_array[i+1])
						curve.add_point(cursor)
						i += 1
				"V":
					while string_array[i+1].is_valid_float():
						cursor.y = float(string_array[i+1])
						curve.add_point(cursor)
						i += 1
				"h":
					while string_array[i+1].is_valid_float():
						cursor.x += float(string_array[i+1])
						curve.add_point(cursor)
						i += 1
				"H":
					while string_array[i+1].is_valid_float():
						cursor.x = float(string_array[i+1])
						curve.add_point(cursor)
						i += 1
				"l":
					while string_array.size() > i + 2 and string_array[i+1].is_valid_float():
						cursor += Vector2(float(string_array[i+1]), float(string_array[i+2]))
						curve.add_point(cursor)
						i += 2
				"L":
					while string_array.size() > i + 2 and string_array[i+1].is_valid_float():
						cursor = Vector2(float(string_array[i+1]), float(string_array[i+2]))
						curve.add_point(cursor)
						i += 2
				"c":
					while string_array.size() > i + 6 and string_array[i+1].is_valid_float():
						var c_out := Vector2(float(string_array[i+1]), float(string_array[i+2]))
						var c_2 :=  Vector2(float(string_array[i+3]), float(string_array[i+4]))
						var c_in_absolute = cursor + c_2
						curve.set_point_out(curve.get_point_count() - 1, c_out)
						cursor += Vector2(float(string_array[i+5]), float(string_array[i+6]))
						var c_in = c_in_absolute - cursor
						curve.add_point(cursor)
						curve.set_point_in(curve.get_point_count() - 1, c_in)
						i += 6
				"C":
					while string_array.size() > i + 6 and string_array[i+1].is_valid_float():
						var c_out := Vector2(float(string_array[i+1]), float(string_array[i+2]))
						var prev_point := curve.get_point_position(curve.get_point_count() - 1)
						var c_in := Vector2(float(string_array[i+3]), float(string_array[i+4]))
						curve.set_point_out(curve.get_point_count() - 1, c_out - prev_point)
						cursor = Vector2(float(string_array[i+5]), float(string_array[i+6]))
						curve.add_point(cursor, c_in - cursor)
						i += 6
				"s":
					while string_array.size() > i + 4 and string_array[i+1].is_valid_float():
						var c_out := -curve.get_point_in(curve.get_point_count() - 1)
						var c_2 :=  Vector2(float(string_array[i+1]), float(string_array[i+2]))
						var c_in_absolute = cursor + c_2
						curve.set_point_out(curve.get_point_count() - 1, c_out)
						cursor += Vector2(float(string_array[i+3]), float(string_array[i+4]))
						var c_in = c_in_absolute - cursor
						curve.add_point(cursor)
						curve.set_point_in(curve.get_point_count() - 1, c_in)
						i += 4
				"S":
					while string_array.size() > i + 4 and string_array[i+1].is_valid_float():
						var c_out := -curve.get_point_in(curve.get_point_count() - 1)
						curve.set_point_out(curve.get_point_count() - 1, c_out)
						cursor = Vector2(float(string_array[i+3]), float(string_array[i+4]))
						var c_in := Vector2(float(string_array[i+1]), float(string_array[i+2]))
						curve.add_point(cursor, c_in - cursor)
						i += 4
				"q":
					while string_array.size() > i + 4 and string_array[i+1].is_valid_float():
						var prev_point := curve.get_point_position(curve.get_point_count() - 1)
						var quadratic_control_point = cursor + Vector2(float(string_array[i+1]), float(string_array[i+2]))
						var c_out = (quadratic_control_point - prev_point) * (2.0/3.0)
						cursor += Vector2(float(string_array[i+3]), float(string_array[i+4]))
						var c_in = (quadratic_control_point - cursor) * (2.0/3.0)
						curve.set_point_out(curve.get_point_count() - 1, c_out)
						curve.add_point(cursor, c_in)
						i += 4
				"Q":
					while string_array.size() > i + 4 and string_array[i+1].is_valid_float():
						var prev_point := curve.get_point_position(curve.get_point_count() - 1)
						var quadratic_control_point := Vector2(float(string_array[i+1]), float(string_array[i+2]))
						var c_out = (quadratic_control_point - prev_point) * (2.0/3.0)
						cursor = Vector2(float(string_array[i+3]), float(string_array[i+4]))
						var c_in = (quadratic_control_point - cursor) * (2.0/3.0)
						curve.set_point_out(curve.get_point_count() - 1, c_out)
						curve.add_point(cursor, c_in)
						i += 4
				"t":
					while string_array.size() > i + 2 and string_array[i+2].is_valid_float():
						var c_out := -curve.get_point_in(curve.get_point_count() - 1)
						var quadratic_control_point := curve.get_point_position(curve.get_point_count() - 1) + (c_out / (2.0/3.0))
						curve.set_point_out(curve.get_point_count() - 1, c_out)
						cursor += Vector2(float(string_array[i+1]), float(string_array[i+2]))
						var c_in = (quadratic_control_point - cursor) * (2.0/3.0)
						curve.add_point(cursor, c_in)
						i += 2
				"T":
					while string_array.size() > i + 2 and string_array[i+2].is_valid_float():
						var c_out := -curve.get_point_in(curve.get_point_count() - 1)
						var quadratic_control_point := curve.get_point_position(curve.get_point_count() - 1) + (c_out / (2.0/3.0))
						curve.set_point_out(curve.get_point_count() - 1, c_out)
						cursor = Vector2(float(string_array[i+1]), float(string_array[i+2]))
						var c_in = (quadratic_control_point - cursor) * (2.0/3.0)
						curve.add_point(cursor, c_in)
						i += 2
				"a":
					while string_array.size() > i + 7 and string_array[i+1].is_valid_float():
						arcs.append(ScalableArc.new(
								curve.point_count - 1,
								Vector2(float(string_array[i+1]), float(string_array[i+2])),
								float(string_array[i+3]),
								int(string_array[i+4]) == 1,
								int(string_array[i+5]) == 1
						))
						cursor += Vector2(float(string_array[i+6]), float(string_array[i+7]))
						curve.add_point(cursor)
						i += 7
				"A":
					while string_array.size() > i + 7 and string_array[i+1].is_valid_float():
						arcs.append(ScalableArc.new(
								curve.point_count - 1,
								Vector2(float(string_array[i+1]), float(string_array[i+2])),
								float(string_array[i+3]),
								int(string_array[i+4]) == 1,
								int(string_array[i+5]) == 1
						))
						cursor = Vector2(float(string_array[i+6]), float(string_array[i+7]))
						curve.add_point(cursor)
						i += 7
				"z", "Z":
					cursor = cursor_start
		if curve.get_point_count() > 1:
			var id = element.get_named_attribute_value("id") if element.has_attribute("id") else "Path"
			if (string_array_count > 1 and Geometry2D.is_point_in_polygon(curve.get_point_position(0),
						main_shape.transform * main_shape.tessellate() )):
				new_clip_paths.append(create_path2d("CutoutFor%s" % id, current_node,  curve, arcs,
							Transform2D.IDENTITY, {}, scene_root, gradients,
							string_array[string_array.size()-1].to_upper() == "Z", main_shape))
			else:
				var result := create_path2d(id, current_node,  curve, arcs, get_svg_transform(element),
							element.get_merged_styles(log_message), scene_root, gradients,
							string_array[string_array.size()-1].to_upper() == "Z")
				if string_array_count == 1:
					main_shape = result

	if not new_clip_paths.is_empty():
		log_message("Processing %d cutouts for %s" % [new_clip_paths.size(), main_shape.name], LogLevel.DEBUG)
		main_shape.clip_paths = new_clip_paths
		undo_redo.add_do_property(main_shape, 'clip_paths', new_clip_paths)
		undo_redo.add_undo_property(main_shape, 'clip_paths', [])




func create_path2d(path_name: String, parent: Node, curve: Curve2D, arcs: Array[ScalableArc],
						transform: Transform2D, style: Dictionary, scene_root: Node,
						gradients : Array[Dictionary], is_closed := false,
						is_cutout_for : ScalableVectorShape2D = null) -> ScalableVectorShape2D:
	var new_path = ScalableVectorShape2D.new()
	new_path.name = path_name
	new_path.curve = curve
	new_path.arc_list = ScalableArcList.new(arcs)
	if (is_closed and curve.point_count > 1 and  curve.get_point_position(0).distance_to(
				curve.get_point_position(curve.point_count - 1)) > 0.001):
		curve.add_point(curve.get_point_position(0))

	if is_cutout_for:
		new_path.transform = is_cutout_for.transform.affine_inverse()
		new_path.set_position_to_center()
		_post_process_shape(new_path, is_cutout_for, transform, style, scene_root, gradients, true)
	else:
		new_path.set_position_to_center()
		_post_process_shape(new_path, parent, transform, style, scene_root, gradients, false)
	return new_path


func _apply_clip_path_by_href(href : String, svs : ScalableVectorShape2D, scene_root : Node):
	var clip_path_node := scene_root.find_child(href.replace("url(#", "").replace(")", ""))
	var new_clip_paths : Array[ScalableVectorShape2D] = []
	for clip_path : ScalableVectorShape2D in clip_path_node.find_children("*", "ScalableVectorShape2D"):
		clip_path.use_interect_when_clipping = true
		if clip_path.line:
			clip_path.line.hide()
		if clip_path.polygon:
			clip_path.polygon.hide()
		var applied_clip_path = clip_path.duplicate()
		new_clip_paths.append(applied_clip_path)
		_managed_add_child_and_set_owner(svs.get_parent(), applied_clip_path, scene_root)

	log_message("Processing %d clip-paths for %s" % [new_clip_paths.size(), svs.name], LogLevel.DEBUG)
	svs.clip_paths = new_clip_paths
	undo_redo.add_do_property(svs, 'clip_paths', new_clip_paths)
	undo_redo.add_undo_property(svs, 'clip_paths', [])


func _post_process_shape(svs : ScalableVectorShape2D, parent : Node, transform : Transform2D,
			style : Dictionary, scene_root : Node, gradients : Array[Dictionary],
			is_cutout := false, image_texture : ImageTexture = null) -> void:
	svs.lock_assigned_shapes = import_as_svs and lock_shapes
	svs.update_curve_at_runtime = CurvedLines2D._is_setting_update_curve_at_runtime()
	svs.arc_list.resource_local_to_scene = CurvedLines2D._is_making_curve_resources_local_to_scene()
	svs.curve.resource_local_to_scene = CurvedLines2D._is_making_curve_resources_local_to_scene()
	svs.tolerance_degrees = CurvedLines2D._get_default_tolerance_degrees()
	svs.max_stages = CurvedLines2D._get_default_max_stages()
	var gradient_point_parent : Node2D = parent
	if transform == Transform2D.IDENTITY:
		_managed_add_child_and_set_owner(parent, svs, scene_root)
	else:
		var transform_node := Node2D.new()
		transform_node.name = svs.name + "Transform"
		transform_node.transform = transform
		_managed_add_child_and_set_owner(parent, transform_node, scene_root)
		_managed_add_child_and_set_owner(transform_node, svs, scene_root)
		gradient_point_parent = transform_node

	if style.has("opacity"):
		svs.modulate.a = float(style["opacity"])

	if style.is_empty() or ("fill" not in style and "stroke" not in style):
		style["fill"] = "#000000"

	if style.has("display") and style['display'] == "none":
		svs.visible = false

	if not is_cutout:
		for func_name in PAINT_ORDER_MAP[get_paint_order(style)]:
			call(func_name, svs, style, scene_root, gradients,
					gradient_point_parent, image_texture)

	if "clip-path" in style:
		_apply_clip_path_by_href(style["clip-path"], svs, scene_root)


func get_paint_order(style : Dictionary) -> String:
	if style.has("paint-order") and style['paint-order'] in PAINT_ORDER_MAP:
		return style['paint-order']
	else:
		return "normal"


func add_stroke_to_path(new_path : ScalableVectorShape2D, style: Dictionary, scene_root : Node,
			gradients : Array[Dictionary], gradient_point_parent : Node2D,
			_image_texture : ImageTexture):
	if style.has("stroke") and style["stroke"] != "none":
		var stroke : Node2D = Line2D.new() if import_stroke_as_line_2d else Polygon2D.new()
		var prop_name := "line" if import_stroke_as_line_2d else "poly_stroke"
		stroke.name = "Stroke"
		stroke.antialiased = antialiased_shapes
		_managed_add_child_and_set_owner(new_path, stroke, scene_root, prop_name)
		if style["stroke"].begins_with("url"):
			if stroke is Line2D:
				log_message("⚠️ Gradient stroke style not supported by Line2D: " + style["stroke"])
			else:
				var href : String = style["stroke"].replace("url(", "").replace(")", "")
				var svg_gradient = get_gradient_by_href(href, gradients)
				if svg_gradient.is_empty():
					log_message("⚠️ Cannot find gradient for href=%s" % href, LogLevel.WARN)
				else:
					add_gradient_to_fill(new_path, svg_gradient, stroke, scene_root, gradients, gradient_point_parent)
		elif style["stroke"].begins_with("rgba"):
			var parts := _parse_svg_transform_params(style["stroke"].replace("rgba", ""))
			new_path.stroke_color = Color.from_rgba8(parts[0], parts[1], parts[2], parts[3])
		elif style["stroke"].begins_with("rgb"):
			var parts := _parse_svg_transform_params(style["stroke"].replace("rgb", ""))
			new_path.stroke_color = Color.from_rgba8(parts[0], parts[1], parts[2])
		else:
			new_path.stroke_color = Color(style["stroke"])
		if style.has("stroke-width"):
			new_path.stroke_width = float(style['stroke-width'])
		if style.has("stroke-opacity"):
			new_path.stroke_color.a = float(style["stroke-opacity"])

		if style.has("stroke-linecap") and style["stroke-linecap"] in  STROKE_CAP_MAP:
			new_path.end_cap_mode = STROKE_CAP_MAP[style["stroke-linecap"]]
			new_path.begin_cap_mode = STROKE_CAP_MAP[style["stroke-linecap"]]
		else:
			new_path.end_cap_mode = Line2D.LINE_CAP_NONE
			new_path.begin_cap_mode = Line2D.LINE_CAP_NONE

		if style.has("stroke-linejoin") and style["stroke-linejoin"] in STROKE_JOINT_MAP:
			new_path.line_joint_mode = STROKE_JOINT_MAP[style["stroke-linejoin"]]
		else:
			new_path.line_joint_mode = Line2D.LINE_JOINT_SHARP
		if stroke is Line2D:
			if style.has("stroke-miterlimit"):
				stroke.sharp_limit = float(style["stroke-miterlimit"])
			else:
				stroke.sharp_limit = 4.0 # svg default



func add_fill_to_path(new_path : ScalableVectorShape2D, style: Dictionary, scene_root : Node,
			gradients : Array[Dictionary], gradient_point_parent : Node2D,
			image_texture : ImageTexture):

	if image_texture or style.has("fill") and style["fill"] != "none":
		var polygon := Polygon2D.new()
		polygon.name = "Fill"
		polygon.antialiased = antialiased_shapes
		_managed_add_child_and_set_owner(new_path, polygon, scene_root, 'polygon')
		if image_texture != null:
			var box := new_path.get_bounding_rect()
			polygon.texture = image_texture
			polygon.texture_offset = -box.position
			polygon.texture_scale = polygon.texture.get_size() / box.size
		elif style["fill"].begins_with("url"):
			var href : String = style["fill"].replace("url(", "").replace(")", "")
			var svg_gradient = get_gradient_by_href(href, gradients)
			if svg_gradient.is_empty():
				log_message("⚠️ Cannot find gradient for href=%s" % href, LogLevel.WARN)
			else:
				add_gradient_to_fill(new_path, svg_gradient, polygon, scene_root, gradients, gradient_point_parent)
		elif style["fill"].begins_with("rgba"):
			var parts := _parse_svg_transform_params(style["fill"].replace("rgba", ""))
			polygon.color = Color.from_rgba8(parts[0], parts[1], parts[2], parts[3])
		elif style["fill"].begins_with("rgb"):
			var parts := _parse_svg_transform_params(style["fill"].replace("rgb", ""))
			polygon.color = Color.from_rgba8(parts[0], parts[1], parts[2])
		else:
			polygon.color = Color(style["fill"])
			if style.has("fill-opacity"):
				polygon.color.a = float(style["fill-opacity"])


func add_collision_to_path(new_path : ScalableVectorShape2D, style : Dictionary, scene_root : Node,
			_gradients : Array[Dictionary], _gradient_point_parent : Node2D,
			_image_texture : ImageTexture) -> void:
	if collision_object_type != ScalableVectorShape2D.CollisionObjectType.NONE:
		match collision_object_type:
			ScalableVectorShape2D.CollisionObjectType.STATIC_BODY_2D:
				_managed_add_child_and_set_owner(new_path, StaticBody2D.new(), scene_root, 'collision_object')
			ScalableVectorShape2D.CollisionObjectType.AREA_2D:
				_managed_add_child_and_set_owner(new_path, Area2D.new(), scene_root, 'collision_object')
			ScalableVectorShape2D.CollisionObjectType.ANIMATABLE_BODY_2D:
				_managed_add_child_and_set_owner(new_path, AnimatableBody2D.new(), scene_root, 'collision_object')
			ScalableVectorShape2D.CollisionObjectType.RIGID_BODY_2D:
				_managed_add_child_and_set_owner(new_path, RigidBody2D.new(), scene_root, 'collision_object')
			ScalableVectorShape2D.CollisionObjectType.CHARACTER_BODY_2D:
				_managed_add_child_and_set_owner(new_path, CharacterBody2D.new(), scene_root, 'collision_object')
			ScalableVectorShape2D.CollisionObjectType.PHYSICAL_BONE_2D:
				_managed_add_child_and_set_owner(new_path, PhysicalBone2D.new(), scene_root, 'collision_object')


func add_gradient_to_fill(new_path : ScalableVectorShape2D, svg_gradient: Dictionary, polygon : Polygon2D,
		scene_root : Node, gradients : Array[Dictionary], gradient_point_parent : Node2D) -> void:
	if "xlink:href" in svg_gradient:
		svg_gradient.merge(get_gradient_by_href(svg_gradient["xlink:href"], gradients), false)
	elif "href" in svg_gradient:
		svg_gradient.merge(get_gradient_by_href(svg_gradient["href"], gradients), false)

	var texture := GradientTexture2D.new()
	var box := new_path.get_bounding_rect()
	texture.width = ceil(box.size.x)
	texture.height = ceil(box.size.y)
	texture.gradient = Gradient.new()
	var stops = svg_gradient["stops"] if "stops" in svg_gradient else []
	var gradient_data := {}
	for i in range(stops.size()):
		var stop_style = stops[i]["style"] if "style" in stops[i] else { "stop-color": "#ffffff" }
		var stop_color = stop_style["stop-color"] if "stop-color" in stop_style else "#ffffff"
		var stop_opacity = stop_style["stop-opacity"] if "stop-opacity" in stop_style else "1"
		gradient_data[float(stops[i]["offset"])] = Color(stop_color, float(stop_opacity))
	texture.gradient.colors = gradient_data.values()
	texture.gradient.offsets = gradient_data.keys()

	if svg_gradient["is_radial"] and "cx" in svg_gradient and "cy" in svg_gradient and "r" in svg_gradient:
		var gradient_transform = (
			process_svg_transform(svg_gradient["gradientTransform"]) if "gradientTransform" in svg_gradient else
			Transform2D.IDENTITY
		)
		var fill_from = Vector2(float(svg_gradient["cx"]), float(svg_gradient["cy"]))
		var fill_to = fill_from + Vector2.RIGHT * float(svg_gradient["r"])
		apply_gradient(new_path, svg_gradient, polygon, scene_root, gradients, gradient_point_parent,
				box, texture, fill_from, fill_to, gradient_transform)
		texture.fill = GradientTexture2D.FILL_RADIAL
	elif "x1" in svg_gradient and "y1" in svg_gradient and "x2" in svg_gradient and "y2" in svg_gradient:
		var gradient_transform = (
			process_svg_transform(svg_gradient["gradientTransform"]) if "gradientTransform" in svg_gradient else
			Transform2D.IDENTITY
		)
		var fill_from = Vector2(float(svg_gradient["x1"]), float(svg_gradient["y1"]))
		var fill_to = Vector2(float(svg_gradient["x2"]), float(svg_gradient["y2"]))
		apply_gradient(new_path, svg_gradient, polygon, scene_root, gradients, gradient_point_parent,
				box, texture, fill_from, fill_to, gradient_transform)
	polygon.texture_offset = -box.position
	polygon.texture = texture


func apply_gradient(new_path : ScalableVectorShape2D, svg_gradient: Dictionary, polygon : Polygon2D,
		scene_root : Node, gradients : Array[Dictionary], gradient_point_parent : Node2D, box : Rect2,
		texture : GradientTexture2D, fill_from : Vector2, fill_to : Vector2, gradient_transform : Transform2D) -> void:
	var gradient_transform_node = create_helper_node("Gradient(%s)" % new_path.name, gradient_point_parent, scene_root, Vector2.ZERO, gradient_transform)
	var from_node = create_helper_node("From(%s)" % new_path.name, gradient_transform_node, scene_root, fill_from)
	var to_node = create_helper_node("To(%s)" % new_path.name, gradient_transform_node, scene_root, fill_to)
	var box_tl_node = create_helper_node("BoxTopLeft(%s)" % new_path.name, gradient_point_parent, scene_root, new_path.position + box.position)
	var box_br_node = create_helper_node("BoxBottomRight(%s)" % new_path.name, gradient_point_parent, scene_root, box_tl_node.position + box.size)
	texture.fill_from = (from_node.global_position - box_tl_node.global_position) / (box_br_node.global_position - box_tl_node.global_position)
	texture.fill_to = (to_node.global_position - box_tl_node.global_position) / (box_br_node.global_position - box_tl_node.global_position)
	gradient_transform_node.queue_free()
	box_tl_node.queue_free()
	box_br_node.queue_free()


func create_helper_node(node_name : String, node_parent : Node2D, node_owner : Node,
		node_position := Vector2.ZERO, node_transform := Transform2D.IDENTITY) -> Node2D:
	var helper_node := Node2D.new()
	helper_node.name = node_name
	node_parent.add_child(helper_node, true)
	helper_node.set_owner(node_owner)
	if node_position != Vector2.ZERO:
		helper_node.position = node_position
	if node_transform != Transform2D.IDENTITY:
		helper_node.transform = node_transform
	return helper_node


func get_svg_transform(element:SVGXMLElement) -> Transform2D:
	if element.has_attribute("transform"):
		return process_svg_transform(element.get_named_attribute_value("transform"))
	else:
		return Transform2D.IDENTITY


func _parse_svg_transform_params(svg_transform_params : String) -> PackedFloat64Array:
	return (svg_transform_params
		.replace("(", "").replace(")", "").replace(",", " ")
		.split_floats(" ", false))


func process_svg_transform(svg_transform_attr : String) -> Transform2D:
	var svg_commands = (
			Array(svg_transform_attr.split(")", false))
					.map(func(cmd): return cmd.lstrip(" \t\r\n") + ")")
	)
	svg_commands.reverse()
	var transform = Transform2D.IDENTITY
	for svg_transform in svg_commands:
		if svg_transform.begins_with("translate"):
			svg_transform = svg_transform.replace("translate", "")
			var transform_split = _parse_svg_transform_params(svg_transform)
			if transform_split.size() >= 2:
				transform = transform.translated(Vector2(transform_split[0], transform_split[1]))
			else:
				transform = transform.translated(Vector2(transform_split[0], transform_split[0]))
		elif svg_transform.begins_with("scale"):
			svg_transform = svg_transform.replace("scale", "")
			var transform_split = _parse_svg_transform_params(svg_transform)
			if transform_split.size() >= 2:
				transform = transform.scaled(Vector2(transform_split[0], transform_split[1]))
			else:
				transform = transform.scaled(Vector2(transform_split[0], transform_split[0]))
		elif svg_transform.begins_with("rotate"):
			svg_transform = svg_transform.replace("rotate", "")
			var transform_split = _parse_svg_transform_params(svg_transform)
			if transform_split.size() == 1:
				transform = transform.rotated(deg_to_rad(transform_split[0]))
			elif transform_split.size() == 3:
				transform = transform.translated(-Vector2(transform_split[1], transform_split[2]))
				transform = transform.rotated(deg_to_rad(transform_split[0]))
				transform = transform.translated(Vector2(transform_split[1], transform_split[2]))
		elif svg_transform.begins_with("matrix"):
			svg_transform = svg_transform.replace("matrix", "")
			var matrix = _parse_svg_transform_params(svg_transform)
			for i in 3:
				transform[i] = Vector2(matrix[i*2], matrix[i*2+1])
	return transform


func _managed_add_child_and_set_owner(parent : Node, child : Node,
		scene_root : Node, as_property := ""):
	parent.add_child(child, true)
	child.set_owner(scene_root)
	undo_redo.add_do_method(parent, 'add_child', child, true)
	undo_redo.add_do_method(child, 'set_owner', scene_root)
	undo_redo.add_do_reference(child)
	undo_redo.add_undo_method(parent, 'remove_child', child)
	if not as_property.is_empty():
		parent.call("set", as_property, child)
		undo_redo.add_do_property(parent, as_property, child)


static func parse_attribute_string(raw_attribute_str : String) -> String:
	var regex = RegEx.new()
	regex.compile("\\S+")
	var str_path = ""
	for result  in regex.search_all(raw_attribute_str):
		str_path += result.get_string() + " "
	return str_path.strip_edges()


func _on_collision_object_type_option_button_type_selected(obj_type: ScalableVectorShape2D.CollisionObjectType) -> void:
	collision_object_type = obj_type


func _on_keep_drawable_path_2d_node_check_box_toggled(toggled_on: bool) -> void:
	import_as_svs = toggled_on
	%LockShapesCheckBox.visible = toggled_on


func _on_lock_shapes_check_box_toggled(toggled_on: bool) -> void:
	lock_shapes = toggled_on


func _on_antialiased_check_box_toggled(toggled_on: bool) -> void:
	antialiased_shapes = toggled_on


func _on_open_file_dialog_button_pressed() -> void:
	import_file_dialog.popup_file_dialog()


func _on_use_line_2d_check_box_toggled(toggled_on: bool) -> void:
	import_stroke_as_line_2d = toggled_on
