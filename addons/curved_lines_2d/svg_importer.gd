@tool
class_name SVGImporter extends Object

# Fraction of a radius for a bezier control point
const R_TO_CP = 0.5523
const PLC_EXP = "__PLC_EXP__"

const SVG_ROOT_META_NAME := "svg_root"
const SVG_STYLE_META_NAME := "svg_style"

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

## Import an svg file as [ScaleableVectorShape2D]s.
static func load_svg(file_path : String, import_settings := {}, logger := func(msg : String, log_level := LogLevel.INFO): print(msg)) -> Node:
	var xml_parser = XMLParser.new()
	if xml_parser.open(file_path) != OK:
		logger.call("ERROR: Failed to open %s for reading" % file_path, LogLevel.ERROR)
		return
	var svg_xml_node : SVGXMLElement = parse_svg_xml_file(xml_parser)
	
	logger.call("Importing SVG file: %s" % file_path, LogLevel.INFO)
	var svg_output := process_svg_xml_tree(svg_xml_node, [], import_settings, logger)
	if svg_output.size() != 1:
		logger.call("ERROR: SVG file %s parse incorrectly - more than one root node" % file_path, LogLevel.DEBUG)
		return
	svg_output[0].name = file_path.get_file().replace(".svg", "").to_pascal_case()
	svg_output[0].set_meta(SVG_ROOT_META_NAME, true)
	return svg_output[0]

## Convert raw svg file into tree structure
static func parse_svg_xml_file(xml_parser : XMLParser) -> SVGXMLElement:
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
			var name = xml_parser.get_node_name()
			var attributes : Dictionary[String, String]= {}
			for i in xml_parser.get_attribute_count():
				attributes[xml_parser.get_attribute_name(i)] = xml_parser.get_attribute_value(i)
			var new_svg_xml_node := SVGXMLElement.new(name, attributes, svg_xml_node)
			if svg_xml_node:
				svg_xml_node.add_child(new_svg_xml_node)
			if not xml_parser.is_empty():
				svg_xml_node = new_svg_xml_node
	return svg_xml_node

## Recursively turn an [SVGXMLElement] tree into [ScaleableVectorShape2D]s.
static func process_svg_xml_tree(xml_data : SVGXMLElement, svg_gradients : Array[Dictionary], import_settings: Dictionary, logger : Callable, defs : Node = null) -> Array:
	if xml_data.name == "use": derefrence_use_tag(xml_data, logger)
	
	match xml_data.name:
		"svg":
			return [process_svg(xml_data, svg_gradients, import_settings, logger)]
		"g", "clipPath", "defs":
			return [process_group(xml_data, svg_gradients, import_settings, defs, logger)]
		"rect":
			return process_svg_rectangle(xml_data, svg_gradients, import_settings, defs, logger)
		"image":
			return process_svg_image(xml_data, svg_gradients, import_settings, defs, logger)
		"polygon":
			return process_svg_polygon(xml_data, true, svg_gradients, import_settings, defs, logger)
		"polyline":
			return process_svg_polygon(xml_data, false, svg_gradients, import_settings, defs, logger)
		"path":
			return process_svg_path(xml_data, svg_gradients, import_settings, defs, logger)
		"circle":
			return process_svg_circle(xml_data, svg_gradients, import_settings, defs, logger)
		"ellipse":
			return process_svg_ellipse(xml_data, svg_gradients, import_settings, defs, logger)
		"linearGradient", "radialGradient":
			svg_gradients.append(parse_gradient(xml_data, logger))
		"stop":
			pass
		_: logger.call("⚠️ Skipping  unsupported node: <%s>" % xml_data.name, LogLevel.DEBUG)
	return []

## Convert "use" xml tag to something actually importable
static func derefrence_use_tag(xml_data: SVGXMLElement, logger : Callable):
	var href = xml_data.get_named_attribute_value_safe("xlink:href")
	if href.is_empty():
		href = xml_data.get_named_attribute_value_safe("href")
	var reuse_xml_node = xml_data.find_by_id(href.replace("#", ""))
	var style = xml_data.get_svg_style(logger)
	style.merge(reuse_xml_node.get_merged_styles(logger))
	var preserve_id := xml_data.get_named_attribute_value_safe("id")
	xml_data.attributes.erase("xlink:href")
	xml_data.attributes.merge(reuse_xml_node.attributes)
	xml_data.attributes["id"] = preserve_id
	xml_data.attributes["style"] = "; ".join(style.keys().map(func(k): return k + ": " + style[k]))
	if preserve_id.is_empty():
		xml_data.attributes.erase("id")
	xml_data.name = reuse_xml_node.name

static func get_gradient_by_href(href : String, gradients : Array[Dictionary]) -> Dictionary:
	var idx := gradients.find_custom(func(x): return "id" in x and "#" + x["id"] == href)
	if idx < 0:
		return {}
	return gradients[idx]

static func parse_gradient(gradient_xml : SVGXMLElement, logger : Callable) -> Dictionary:
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
					"style": element.get_merged_styles(logger),
					"offset": float(element.get_named_attribute_value_safe("offset")),
					"id": element.get_named_attribute_value_safe("id")
				})

	return new_gradient

static func get_element_label(element: SVGXMLElement, alt_name : String) -> String:
	if element.has_attribute("inkscape:label"):
		return element.get_named_attribute_value("inkscape:label")
	elif element.has_attribute("id"):
		return element.get_named_attribute_value("id")
	return alt_name

static func process_svg(xml_data: SVGXMLElement, svg_gradients : Array[Dictionary], import_settings : Dictionary, logger : Callable) -> Node2D:
	var top_level_svg_node := Node2D.new()
	if xml_data.has_attribute("viewBox") and xml_data.has_attribute("width") and xml_data.has_attribute("height"):
		var view_box = xml_data.get_named_attribute_value("viewBox").split_floats(" ")
		var width := float(xml_data.get_named_attribute_value("width"))
		var height := float(xml_data.get_named_attribute_value("height"))
		top_level_svg_node.scale.x = width / view_box[2]
		top_level_svg_node.scale.y = height / view_box[3]
		if xml_data.get_named_attribute_value("width").ends_with("mm"): # unit conversion to pixel
			logger.call("⚠️ Units for this image are millimeters (mm), image scale set to 3.78", LogLevel.INFO)
			top_level_svg_node.scale *= 3.78
		elif xml_data.get_named_attribute_value("width").ends_with("cm"):
			logger.call("⚠️ Units for this image are centimeters (cm), image scale set to 37.8", LogLevel.INFO)
			top_level_svg_node.scale *= 37.8
	if xml_data.has_attribute("style"):
		top_level_svg_node.set_meta(SVG_STYLE_META_NAME, xml_data.get_merged_styles(logger))
	var defs : Node = null
	for child in xml_data.children:
		var child_output := process_svg_xml_tree(child,svg_gradients, import_settings, logger, defs)
		for grandchild in child_output:
			if child.name == "defs": defs = grandchild
			elif child_output: top_level_svg_node.add_child(grandchild,true)
	return top_level_svg_node

static func process_group(xml_data:SVGXMLElement, svg_gradients : Array[Dictionary], import_settings : Dictionary, defs : Node, logger : Callable) -> Node2D:
	var new_group = Node2D.new()
	new_group.name = get_element_label(xml_data, xml_data.name if xml_data.name != "g" else "Group")
	new_group.transform = get_svg_transform(xml_data)
	var style := xml_data.get_merged_styles(logger)
	new_group.set_meta(SVG_STYLE_META_NAME, style)

	if style.has("display") and style['display'] == "none":
		new_group.visible = false
	for child in xml_data.children:
		var child_output := process_svg_xml_tree(child, svg_gradients, import_settings, logger, defs)
		for grandchild in child_output:
			new_group.add_child(grandchild,true)
	new_group.visible = xml_data.name == "g"
	return new_group

static func process_svg_circle(element:SVGXMLElement,
		gradients : Array[Dictionary], import_settings : Dictionary, defs : Node, logger : Callable = func(mesg : String): pass) -> Array[ScalableVectorShape2D]:
	var cx = float(element.get_named_attribute_value("cx"))
	var cy = float(element.get_named_attribute_value("cy"))
	var r = float(element.get_named_attribute_value("r"))
	var path_name = get_element_label(element, "Circle")
	return create_path_from_ellipse(element, path_name, r, r, Vector2(cx, cy), gradients, import_settings, defs, logger)


static func process_svg_ellipse(element:SVGXMLElement, 
		gradients : Array[Dictionary], import_settings : Dictionary, defs : Node, logger : Callable = func(mesg : String): pass) -> Array[ScalableVectorShape2D]:
	var cx = float(element.get_named_attribute_value("cx"))
	var cy = float(element.get_named_attribute_value("cy"))
	var rx = float(element.get_named_attribute_value("rx"))
	var ry = float(element.get_named_attribute_value("ry"))
	var path_name = get_element_label(element, "Ellipse")
	return create_path_from_ellipse(element, path_name, rx, ry, Vector2(cx, cy), gradients, import_settings, defs, logger)


static func create_path_from_ellipse(element:SVGXMLElement, path_name : String, rx : float, ry: float,
		pos : Vector2, 
		gradients : Array[Dictionary], import_settings : Dictionary, defs : Node, logger : Callable) -> Array[ScalableVectorShape2D]:
	var new_ellipse := ScalableVectorShape2D.new()
	new_ellipse.shape_type = ScalableVectorShape2D.ShapeType.ELLIPSE
	new_ellipse.size = Vector2(rx * 2, ry * 2)
	new_ellipse.position = pos
	new_ellipse.name = path_name
	return _post_process_shape(new_ellipse, import_settings, defs, get_svg_transform(element),
			element.get_merged_styles(logger), gradients)

static func process_svg_image(element:SVGXMLElement,
		gradients : Array[Dictionary], import_settings : Dictionary, defs : Node, logger : Callable) -> Array[ScalableVectorShape2D]:
	var x = float(element.get_named_attribute_value("x")) if element.has_attribute("x") else 0.0
	var y = float(element.get_named_attribute_value("y")) if element.has_attribute("y") else 0.0
	var width = float(element.get_named_attribute_value("width"))
	var height = float(element.get_named_attribute_value("height"))
	var new_image_rect := ScalableVectorShape2D.new()
	new_image_rect.shape_type = ScalableVectorShape2D.ShapeType.RECT
	new_image_rect.size = Vector2(width, height)
	new_image_rect.position = Vector2(x, y) + new_image_rect.size * 0.5
	new_image_rect.name = get_element_label(element, "Image")
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
		logger.call("Parsed image format: %s" % format, LogLevel.DEBUG)
	else:
		logger.call("⚠️ Only base64 encoded embedded images are supported", LogLevel.WARN)

	return _post_process_shape(new_image_rect, import_settings, defs, get_svg_transform(element),
			element.get_merged_styles(logger), gradients, false, image_texture)

static func process_svg_rectangle(element:SVGXMLElement,
		gradients : Array[Dictionary], import_settings : Dictionary, defs : Node, logger : Callable) -> Array[ScalableVectorShape2D]:
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
	new_rect.name = get_element_label(element, "Rectangle")
	return _post_process_shape(new_rect, import_settings, defs, get_svg_transform(element),
			element.get_merged_styles(logger), gradients)


static func process_svg_polygon(element:SVGXMLElement, is_closed : bool,
		gradients : Array[Dictionary], import_settings : Dictionary, defs : Node, logger : Callable) -> Array[ScalableVectorShape2D]:
	var points_split = (element.get_named_attribute_value("points")
			.replacen(",", " ")
			.split(" ", false)
	)
	var curve = Curve2D.new()
	for p_idx in range(0, points_split.size(), 2):
		curve.add_point(Vector2(float(points_split[p_idx]), float(points_split[p_idx + 1])))
	var path_name = get_element_label(element, "Polygon" if is_closed else "Polyline")

	return create_path2d(path_name, curve, [], import_settings, defs, get_svg_transform(element),
			element.get_merged_styles(logger), gradients, is_closed)



static func process_svg_path(element:SVGXMLElement,
		gradients : Array[Dictionary], import_settings : Dictionary, defs : Node, logger : Callable) -> Array[ScalableVectorShape2D]:

	# FIXME: implement better parsing here
	var str_path = parse_attribute_string(
				element.get_named_attribute_value("d")).replacen(",", " ")
	var shape_name := get_element_label(element, "Path")

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
		logger.call("⚠️ Support for the m/M (move to) command is limited to cut-outs in svg paths", LogLevel.WARN)
	var string_array_count = 0
	var cursor = Vector2.ZERO
	var shapes : Array[ScalableVectorShape2D] = []
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
		# Add a new ScalableVectorShape2D to the list for this section of
		# the path definition (`d`-attribute of the path element)
		var shape := ScalableVectorShape2D.new()
		shape.name = shape_name
		shape.curve = curve
		shape.arc_list = ScalableArcList.new(arcs)
		shape.set_meta("is_closed", string_array[string_array.size()-1].to_upper() == "Z")
		shapes.append(shape)

	logger.call("Postprocessing for %s" % shape_name, LogLevel.DEBUG)
	# Loop through al the shapes in this <path> element looking for holes
	# if a shape is a hole, make sure it is not in the post_processed_shapes
	# array after this loop, but a member of the surrounding shape's clip_paths
	# array.
	var post_processed_shapes : Array[ScalableVectorShape2D] = []
	for shape : ScalableVectorShape2D in shapes:
		var poly := shape.tessellate()
		post_processed_shapes.append(shape)
		for shape1 : ScalableVectorShape2D in shapes:
			if shape1 == shape:
				continue
			var poly1 := shape1.tessellate()
			var res := Geometry2D.intersect_polygons(poly, poly1)
			if res.size() > 0:
				if Geometry2D.is_point_in_polygon(poly[0], poly1):
					if shape not in shape1.clip_paths:
						shape1.clip_paths.append(shape)
					post_processed_shapes.erase(shape)
				else:
					if shape1 not in shape.clip_paths:
						shape.clip_paths.append(shape1)
					post_processed_shapes.erase(shape1)

	var path_shapes : Array[ScalableVectorShape2D] = []
	# Append actual new shapes to the scene by copying the `curve`, `arc_list` and
	# `clip_paths`. Also, the shapes inside the `clip_paths` property are added as
	# actual node in the resulting scene
	for shape in post_processed_shapes:
		var new_path := create_path2d(shape_name, shape.curve.duplicate(true), 
					shape.arc_list.arcs.duplicate(true), import_settings, defs, get_svg_transform(element),
					element.get_merged_styles(logger), gradients, shape.get_meta("is_closed"))
		path_shapes.append_array(new_path)
		var clips : Array[ScalableVectorShape2D] = []
		for cutout in shape.clip_paths:
			var new_clip_path := create_path2d("CutoutFor%s" % shape_name, cutout.curve.duplicate(true), cutout.arc_list.arcs.duplicate(true), 
						import_settings, defs, Transform2D.IDENTITY, {},  gradients, cutout.get_meta("is_closed"), new_path[-1])
			clips.append_array(new_clip_path)
			cutout.free()
		shape.free()
		# append_array is used here, because clip paths may already have been added via the
		# `create_path2d(...)` call chain.
		new_path[-1].clip_paths.append_array(clips)
	return path_shapes


static func create_path2d(path_name: String,  curve: Curve2D, arcs: Array[ScalableArc], 
						import_settings : Dictionary, defs : Node, transform: Transform2D, 
						style: Dictionary, gradients : Array[Dictionary], is_closed := false,
						is_cutout_for : ScalableVectorShape2D = null) -> Array[ScalableVectorShape2D]:
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
		return _post_process_shape(new_path, import_settings, defs, transform, style, gradients, true)
	else:
		new_path.set_position_to_center()
		return _post_process_shape(new_path, import_settings, defs, transform, style, gradients, false)


static func _post_process_shape(svs : ScalableVectorShape2D, import_settings : Dictionary, defs: Node,
			transform : Transform2D, style : Dictionary, gradients : Array[Dictionary],
			is_cutout := false, image_texture : ImageTexture = null, logger : Callable = func(msg,lvl): pass) -> Array[ScalableVectorShape2D]:
	svs.lock_assigned_shapes = import_settings.get("import_as_svs", true) and import_settings.get("lock_shapes", true)
	svs.update_curve_at_runtime = import_settings.get("update_curve_at_runtime", false)
	svs.arc_list.resource_local_to_scene = import_settings.get("resource_local_to_scene",true)
	svs.curve.resource_local_to_scene = import_settings.get("resource_local_to_scene",true)
	svs.tolerance_degrees = import_settings.get("tolerance_degrees", 4.0)
	svs.max_stages = import_settings.get("max_stages",5)
	var gradient_point_parent : Node2D = svs
	if transform != Transform2D.IDENTITY:
		var transform_node := Node2D.new()
		transform_node.name = svs.name + "Transform"
		transform_node.transform = transform
		transform_node.add_child(svs, true)
		gradient_point_parent = transform_node

	if style.has("opacity"):
		svs.modulate.a = float(style["opacity"])

	if style.is_empty() or ("fill" not in style and "stroke" not in style):
		style["fill"] = "#000000"

	if style.has("display") and style['display'] == "none":
		svs.visible = false


	var PAINT_ORDER_MAP := {
		"normal": [add_fill_to_path, add_stroke_to_path, add_collision_to_path],
		"fill stroke markers": [add_fill_to_path, add_stroke_to_path, add_collision_to_path],
		"stroke fill markers": [add_stroke_to_path, add_fill_to_path, add_collision_to_path],
		"fill markers stroke": [add_fill_to_path, add_collision_to_path, add_stroke_to_path],
		"markers fill stroke": [add_collision_to_path, add_fill_to_path, add_stroke_to_path],
		"stroke markers fill": [add_stroke_to_path, add_collision_to_path, add_fill_to_path],
		"markers stroke fill": [add_collision_to_path, add_stroke_to_path, add_fill_to_path]
	}
	if not is_cutout:
		for paint_func : Callable in PAINT_ORDER_MAP[get_paint_order(style)]:
			paint_func.call(svs, style, gradients, import_settings,
					gradient_point_parent, image_texture, logger)

	if "clip-path" in style:
		var svs_clippers = apply_clip_path_by_href(style["clip-path"], defs, svs, logger)
		svs_clippers.append(gradient_point_parent)
		return svs_clippers
	
	return [gradient_point_parent]


static func get_paint_order(style : Dictionary) -> String:
	if style.has("paint-order") and style['paint-order'] in [
		"normal",
		"fill stroke markers",
		"stroke fill markers",
		"fill markers stroke",
		"markers fill stroke",
		"stroke markers fill",
		"markers stroke fill"
		]:
		return style['paint-order']
	else:
		return "normal"

static func apply_clip_path_by_href(href : String, defs : Node, svs : ScalableVectorShape2D, logger : Callable) -> Array[ScalableVectorShape2D]:
	var clip_path_node := defs.find_child(href.replace("url(#", "").replace(")", ""))
	var new_clip_paths : Array[ScalableVectorShape2D] = []
	for clip_path : ScalableVectorShape2D in clip_path_node.find_children("*", "ScalableVectorShape2D"):
		clip_path.use_interect_when_clipping = true
		if clip_path.line:
			clip_path.line.hide()
		if clip_path.polygon:
			clip_path.polygon.hide()
		var applied_clip_path = clip_path.duplicate()
		new_clip_paths.append(applied_clip_path)

	logger.call("Processing %d clip-paths for %s" % [new_clip_paths.size(), svs.name], LogLevel.DEBUG)
	svs.clip_paths = new_clip_paths
	return new_clip_paths


static func add_stroke_to_path(new_path : ScalableVectorShape2D, style: Dictionary,
			gradients : Array[Dictionary], import_settings : Dictionary, gradient_point_parent : Node2D,
			_image_texture : ImageTexture, logger : Callable) -> Node2D:
	if !style.has("stroke") or style["stroke"] == "none": return null
	
	var stroke : Node2D = Line2D.new() if import_settings.get("import_stroke_as_line_2d", true) else Polygon2D.new()
	stroke.name = "Stroke"
	stroke.antialiased = import_settings.get("antialiased_shapes", false)
	new_path.add_child(stroke)
	if import_settings.get("import_stroke_as_line_2d", true):
		new_path.line = stroke
	else:
		new_path.poly_stroke = stroke
	if style["stroke"].begins_with("url"):
		if stroke is Line2D:
			logger.call("⚠️ Gradient stroke style not supported by Line2D: " + style["stroke"], LogLevel.WARN)
		else:
			var href : String = style["stroke"].replace("url(", "").replace(")", "")
			var svg_gradient = get_gradient_by_href(href, gradients)
			if svg_gradient.is_empty():
				logger.call("⚠️ Cannot find gradient for href=%s" % href, LogLevel.WARN)
			else:
				add_gradient_to_fill(new_path, svg_gradient, stroke, gradients, gradient_point_parent)
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
	else:
		new_path.stroke_width = 1.0
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
		if import_settings.get("use_antialiased_line_2d", false):
			stroke.texture = load("res://addons/curved_lines_2d/LumAlpha8.tex")
			stroke.texture_mode = Line2D.LINE_TEXTURE_TILE
			stroke.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return stroke



static func add_fill_to_path(new_path : ScalableVectorShape2D, style: Dictionary,
			gradients : Array[Dictionary], import_settings : Dictionary, gradient_point_parent : Node2D,
			image_texture : ImageTexture, logger : Callable) -> Node2D:
	if !image_texture and (!style.has("fill") or style["fill"] == "none"): return null
	
	var polygon := Polygon2D.new()
	polygon.name = "Fill"
	polygon.antialiased = import_settings.get("antialiased_shapes", false)
	new_path.add_child(polygon)
	new_path.polygon = polygon
	if image_texture != null:
		var box := new_path.get_bounding_rect()
		polygon.texture = image_texture
		polygon.texture_offset = -box.position
		polygon.texture_scale = polygon.texture.get_size() / box.size
	elif style["fill"].begins_with("url"):
		var href : String = style["fill"].replace("url(", "").replace(")", "")
		var svg_gradient = get_gradient_by_href(href, gradients)
		if svg_gradient.is_empty():
			logger.call("⚠️ Cannot find gradient for href=%s" % href, LogLevel.WARN)
		else:
			add_gradient_to_fill(new_path, svg_gradient, polygon, gradients, gradient_point_parent)
	elif style["fill"].begins_with("rgba"):
		var parts := _parse_svg_transform_params(style["fill"].replace("rgba", ""))
		new_path.fill_color = Color.from_rgba8(parts[0], parts[1], parts[2], parts[3])
	elif style["fill"].begins_with("rgb"):
		var parts := _parse_svg_transform_params(style["fill"].replace("rgb", ""))
		new_path.fill_color = Color.from_rgba8(parts[0], parts[1], parts[2])
	else:
		new_path.fill_color = Color(style["fill"])
		if style.has("fill-opacity"):
			new_path.fill_color.a = float(style["fill-opacity"])
	return polygon


static func add_collision_to_path(new_path : ScalableVectorShape2D, style : Dictionary,
			_gradients : Array[Dictionary], import_settings : Dictionary, _gradient_point_parent : Node2D,
			_image_texture : ImageTexture, logger : Callable) -> Node2D:
	match import_settings.get("collision_object_type",ScalableVectorShape2D.CollisionObjectType.NONE):
		ScalableVectorShape2D.CollisionObjectType.STATIC_BODY_2D:
			return StaticBody2D.new()
		ScalableVectorShape2D.CollisionObjectType.AREA_2D:
			return Area2D.new()
		ScalableVectorShape2D.CollisionObjectType.ANIMATABLE_BODY_2D:
			return AnimatableBody2D.new()
		ScalableVectorShape2D.CollisionObjectType.RIGID_BODY_2D:
			return RigidBody2D.new()
		ScalableVectorShape2D.CollisionObjectType.CHARACTER_BODY_2D:
			return CharacterBody2D.new()
		ScalableVectorShape2D.CollisionObjectType.PHYSICAL_BONE_2D:
			return PhysicalBone2D.new()
	return null


static func add_gradient_to_fill(new_path : ScalableVectorShape2D, svg_gradient: Dictionary, polygon : Polygon2D,
		 gradients : Array[Dictionary], gradient_point_parent : Node2D) -> void:
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
		apply_gradient(new_path, svg_gradient, polygon, gradients, gradient_point_parent,
				box, texture, fill_from, fill_to, gradient_transform)
		texture.fill = GradientTexture2D.FILL_RADIAL
	elif "x1" in svg_gradient and "y1" in svg_gradient and "x2" in svg_gradient and "y2" in svg_gradient:
		var gradient_transform = (
			process_svg_transform(svg_gradient["gradientTransform"]) if "gradientTransform" in svg_gradient else
			Transform2D.IDENTITY
		)
		var fill_from = Vector2(float(svg_gradient["x1"]), float(svg_gradient["y1"]))
		var fill_to = Vector2(float(svg_gradient["x2"]), float(svg_gradient["y2"]))
		apply_gradient(new_path, svg_gradient, polygon, gradients, gradient_point_parent,
				box, texture, fill_from, fill_to, gradient_transform)
	polygon.texture_offset = -box.position
	polygon.texture = texture


static func apply_gradient(new_path : ScalableVectorShape2D, svg_gradient: Dictionary, polygon : Polygon2D, 
		gradients : Array[Dictionary], gradient_point_parent : Node2D, box : Rect2,
		texture : GradientTexture2D, fill_from : Vector2, fill_to : Vector2, gradient_transform : Transform2D) -> void:
	var gradient_transform_node = create_helper_node("Gradient(%s)" % new_path.name, gradient_point_parent, Vector2.ZERO, gradient_transform)
	var from_node = create_helper_node("From(%s)" % new_path.name, gradient_transform_node, fill_from)
	var to_node = create_helper_node("To(%s)" % new_path.name, gradient_transform_node, fill_to)
	var box_tl_node = create_helper_node("BoxTopLeft(%s)" % new_path.name, gradient_point_parent, new_path.position + box.position)
	var box_br_node = create_helper_node("BoxBottomRight(%s)" % new_path.name, gradient_point_parent, box_tl_node.position + box.size)
	texture.fill_from = (from_node.global_position - box_tl_node.global_position) / (box_br_node.global_position - box_tl_node.global_position)
	texture.fill_to = (to_node.global_position - box_tl_node.global_position) / (box_br_node.global_position - box_tl_node.global_position)
	gradient_transform_node.queue_free()
	box_tl_node.queue_free()
	box_br_node.queue_free()


static func create_helper_node(node_name : String, node_parent : Node2D,
		node_position := Vector2.ZERO, node_transform := Transform2D.IDENTITY) -> Node2D:
	var helper_node := Node2D.new()
	helper_node.name = node_name
	node_parent.add_child(helper_node, true)
	if node_position != Vector2.ZERO:
		helper_node.position = node_position
	if node_transform != Transform2D.IDENTITY:
		helper_node.transform = node_transform
	return helper_node


static func get_svg_transform(element:SVGXMLElement) -> Transform2D:
	if element.has_attribute("transform"):
		return process_svg_transform(element.get_named_attribute_value("transform"))
	else:
		return Transform2D.IDENTITY


static func _parse_svg_transform_params(svg_transform_params : String) -> PackedFloat64Array:
	return (svg_transform_params
		.replace("(", "").replace(")", "").replace(",", " ")
		.split_floats(" ", false))


static func process_svg_transform(svg_transform_attr : String) -> Transform2D:
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
				transform = transform.translated(Vector2(transform_split[0], 0))
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

static func parse_attribute_string(raw_attribute_str : String) -> String:
	var regex = RegEx.new()
	regex.compile("\\S+")
	var str_path = ""
	for result  in regex.search_all(raw_attribute_str):
		str_path += result.get_string() + " "
	return str_path.strip_edges()
