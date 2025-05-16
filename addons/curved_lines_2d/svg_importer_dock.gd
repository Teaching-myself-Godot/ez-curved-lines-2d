@tool
extends Control

class_name SvgImporterDock

signal toggle_gui_editing(toggled_on : bool)
signal toggle_gui_hints(toggled_on : bool)

const IMPORT_TAB_NAME :=  "Import SVG File"
const EDIT_TAB_NAME := "Scalable Vector Shapes"
# Fraction of a radius for a bezier control point
const R_TO_CP = 0.5523
const SUPPORTED_STYLES : Array[String] = ["opacity", "stroke", "stroke-width", "stroke-opacity",
		"fill", "fill-opacity", "paint-order"]
const SVG_ROOT_META_NAME := "svg_root"
const SVG_STYLE_META_NAME := "svg_style"

enum LogLevel { DEBUG, INFO, WARN, ERROR }
var undo_redo : EditorUndoRedoManager = null
var log_scroll_container : ScrollContainer = null
var log_container : VBoxContainer = null
var error_label_settings : LabelSettings = null
var warning_label_settings : LabelSettings = null
var info_label_settings : LabelSettings = null
var debug_label_settings : LabelSettings = null

## Settings
var import_collision_polygons := false
var import_collision_polygons_for_all_shapes := false
var import_collision_polygons_for_all_shapes_checkbox : Control = null
var keep_drawable_path_node := true
var lock_shapes_checkbox : Control = null
var lock_shapes := true
var antialiased_shapes := false
var import_file_dialog : EditorFileDialog = null
var warning_dialog : AcceptDialog = null

func _enter_tree() -> void:
	log_scroll_container = find_child("ScrollContainer")
	log_container = find_child("ImportLogContainer")
	import_collision_polygons_for_all_shapes_checkbox = find_child("ImportCollisionPolygonsForAllShapesCheckBox")
	lock_shapes_checkbox = find_child("LockShapesCheckBox")
	error_label_settings = preload("res://addons/curved_lines_2d/error_label_settings.tres")
	warning_label_settings = preload("res://addons/curved_lines_2d/warn_label_settings.tres")
	info_label_settings = preload("res://addons/curved_lines_2d/info_label_settings.tres")
	debug_label_settings = preload("res://addons/curved_lines_2d/debug_label_settings.tres")
	log_scroll_container.get_v_scroll_bar().connect("changed", func(): log_scroll_container.scroll_vertical = log_scroll_container.get_v_scroll_bar().max_value )
	import_file_dialog = EditorFileDialog.new()
	import_file_dialog.add_filter("*.svg", "SVG image")
	import_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	import_file_dialog.file_selected.connect(_load_svg)
	EditorInterface.get_base_control().add_child(import_file_dialog)
	warning_dialog = AcceptDialog.new()
	EditorInterface.get_base_control().add_child(warning_dialog)
	find_child(EDIT_TAB_NAME).warning_dialog = warning_dialog


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
	log_container.add_child(lbl)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	find_child(IMPORT_TAB_NAME).show()
	if _can_drop_data(at_position, data):
		var svg_root = _load_svg(data["files"][0])


func _load_svg(file_path : String) -> Node2D:
	for child in log_container.get_children():
		child.queue_free()
	var xml_data = XMLParser.new()
	var scene_root := EditorInterface.get_edited_scene_root()

	if not scene_root is Node2D:
		log_message("ERROR: Can only import into 2D scene", LogLevel.ERROR)
		return null
	if xml_data.open(file_path) != OK:
		log_message("ERROR: Failed to open %s for reading" % file_path, LogLevel.ERROR)
		return null

	log_message("Importing SVG file: %s" % file_path, LogLevel.INFO)
	var svg_root := Node2D.new()
	svg_root.name = file_path.get_file().replace(".svg", "").capitalize()
	svg_root.set_meta(SVG_ROOT_META_NAME, true)
	scene_root.add_child(svg_root, true)
	svg_root.set_owner(scene_root)
	var current_node := svg_root
	var svg_gradients : Array[Dictionary] = []

	while xml_data.read() == OK:
		if not xml_data.get_node_type() in [XMLParser.NODE_ELEMENT, XMLParser.NODE_ELEMENT_END]:
			continue
		elif xml_data.get_node_name() == "g":
			if xml_data.get_node_type() == XMLParser.NODE_ELEMENT:
				current_node = process_group(xml_data, current_node, scene_root)
			elif xml_data.get_node_type() == XMLParser.NODE_ELEMENT_END:
				if current_node == svg_root:
					printerr("Hierarchy error, current not is already scene root")
					break
				current_node = current_node.get_parent()
		elif xml_data.get_node_name() == "rect":
			process_svg_rectangle(xml_data, current_node, scene_root, svg_gradients)
		elif xml_data.get_node_name() == "polygon":
			process_svg_polygon(xml_data, current_node, scene_root, true, svg_gradients)
		elif xml_data.get_node_name() == "polyline":
			process_svg_polygon(xml_data, current_node, scene_root, false, svg_gradients)
		elif xml_data.get_node_name() == "path":
			process_svg_path(xml_data, current_node, scene_root, svg_gradients)
		elif xml_data.get_node_name() == "circle":
			process_svg_circle(xml_data, current_node, scene_root, svg_gradients)
		elif xml_data.get_node_name() == "ellipse":
			process_svg_ellipse(xml_data, current_node, scene_root, svg_gradients)
		elif xml_data.get_node_name() == "svg":
			if xml_data.has_attribute("viewBox") and xml_data.has_attribute("width") and xml_data.has_attribute("height"):
				var view_box := xml_data.get_named_attribute_value("viewBox").split_floats(" ")
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
		elif xml_data.get_node_name() == "style" and xml_data.get_node_type() == XMLParser.NODE_ELEMENT:
			log_message("⚠️ Skipping <style> node, only inline style attribute and some presentation attributes are supported", LogLevel.WARN)
		elif xml_data.get_node_name() == "defs":
			pass
		elif xml_data.get_node_name() == "linearGradient" or xml_data.get_node_name() == "radialGradient":
			svg_gradients.append(parse_gradient(xml_data))
		elif xml_data.get_node_type() == XMLParser.NODE_ELEMENT:
			log_message("⚠️ Skipping  unsupported node: <%s>" % xml_data.get_node_name(), LogLevel.DEBUG)
	log_message("Import finished.\n\nThe SVG importer is in a very early stage of development.")

	var link_button := LinkButton.new()
	link_button.text = "Click here to report issues or improvement requests on github"
	link_button.uri = "https://github.com/Teaching-myself-Godot/ez-curved-lines-2d/issues"
	log_container.add_child(link_button)
	return svg_root


func get_gradient_by_href(href : String, gradients : Array[Dictionary]) -> Dictionary:
	var idx := gradients.find_custom(func(x): return "id" in x and "#" + x["id"] == href)
	if idx < 0:
		return {}
	return gradients[idx]


func parse_gradient(element : XMLParser) -> Dictionary:
	var new_gradient := {
		'is_radial': element.get_node_name() == "radialGradient"
	}
	for i in range(element.get_attribute_count()):
		new_gradient[element.get_attribute_name(i)] = element.get_attribute_value(i)
	if not element.is_empty():
		new_gradient["stops"] = []
		while element.read() == OK:
			if element.get_node_type() == XMLParser.NODE_ELEMENT and element.get_node_name() == "stop":
				new_gradient["stops"].append({
					"style": get_svg_style(element),
					"offset": float(element.get_named_attribute_value_safe("offset")),
					"id": element.get_named_attribute_value_safe("id")
				})
			elif element.get_node_type() == XMLParser.NODE_ELEMENT_END and element.get_node_name() == "linearGradient":
				break
	return new_gradient


func process_group(element:XMLParser, current_node : Node2D, scene_root : Node2D) -> Node2D:
	var new_group = Node2D.new()
	new_group.name = element.get_named_attribute_value("id") if element.has_attribute("id") else "Group"
	new_group.transform = get_svg_transform(element)
	current_node.add_child(new_group, true)
	new_group.set_owner(scene_root)
	new_group.set_meta(SVG_STYLE_META_NAME, get_svg_style(element))
	return new_group


func process_svg_circle(element:XMLParser, current_node : Node2D, scene_root : Node2D,
		gradients : Array[Dictionary]) -> void:
	var cx = float(element.get_named_attribute_value("cx"))
	var cy = float(element.get_named_attribute_value("cy"))
	var r = float(element.get_named_attribute_value("r"))
	var path_name = element.get_named_attribute_value("id") if element.has_attribute("id") else "Circle"
	create_path_from_ellipse(element, path_name, r, r, Vector2(cx, cy), current_node, scene_root, gradients)


func process_svg_ellipse(element:XMLParser, current_node : Node2D, scene_root : Node2D,
		gradients : Array[Dictionary]) -> void:
	var cx = float(element.get_named_attribute_value("cx"))
	var cy = float(element.get_named_attribute_value("cy"))
	var rx = float(element.get_named_attribute_value("rx"))
	var ry = float(element.get_named_attribute_value("ry"))
	var path_name = element.get_named_attribute_value("id") if element.has_attribute("id") else "Ellipse"
	create_path_from_ellipse(element, path_name, rx, ry, Vector2(cx, cy), current_node, scene_root, gradients)


func create_path_from_ellipse(element:XMLParser, path_name : String, rx : float, ry: float,
		pos : Vector2, current_node : Node2D, scene_root : Node2D,
		gradients : Array[Dictionary]) -> void:
	var curve := Curve2D.new()
	curve.add_point(Vector2(rx, 0), Vector2.ZERO, Vector2(0, ry * R_TO_CP))
	curve.add_point(Vector2(0, ry), Vector2(rx * R_TO_CP, 0), Vector2(-rx * R_TO_CP, 0))
	curve.add_point(Vector2(-rx, 0), Vector2(0, ry * R_TO_CP), Vector2(0, -ry * R_TO_CP))
	curve.add_point(Vector2(0, -ry), Vector2(-rx * R_TO_CP, 0), Vector2(rx * R_TO_CP, 0))
	curve.add_point(Vector2(rx, 0), Vector2(0, -ry * R_TO_CP))
	create_path2d(path_name, current_node, curve,
			get_svg_transform(element),
			get_svg_style(element), scene_root, gradients, true, pos)


func process_svg_rectangle(element:XMLParser, current_node : Node2D, scene_root : Node2D,
		gradients : Array[Dictionary]) -> void:
	var curve := Curve2D.new()
	var x = float(element.get_named_attribute_value("x"))
	var y = float(element.get_named_attribute_value("y"))
	var ry = float(element.get_named_attribute_value("ry")) if element.has_attribute("ry") else 0
	var rx = float(element.get_named_attribute_value("rx")) if element.has_attribute("rx") else ry
	var width = float(element.get_named_attribute_value("width"))
	var height = float(element.get_named_attribute_value("height"))
	if rx == 0 and ry == 0:
		curve.add_point(Vector2.ZERO)
		curve.add_point(Vector2(width, 0))
		curve.add_point(Vector2(width, height))
		curve.add_point(Vector2(0, height))
	else:
		curve.add_point(Vector2(width - rx, 0), Vector2.ZERO, Vector2(rx * R_TO_CP, 0))
		curve.add_point(Vector2(width, ry), Vector2(0, -ry * R_TO_CP))
		curve.add_point(Vector2(width, height - ry), Vector2.ZERO, Vector2(0, ry * R_TO_CP))
		curve.add_point(Vector2(width - rx, height), Vector2(rx * R_TO_CP, 0))
		curve.add_point(Vector2(rx, height), Vector2.ZERO, Vector2(-rx * R_TO_CP, 0))
		curve.add_point(Vector2(0, height - ry), Vector2(0, ry * R_TO_CP))
		curve.add_point(Vector2(0, ry), Vector2.ZERO, Vector2(0, -ry * R_TO_CP))
		curve.add_point(Vector2(rx, 0), Vector2(-rx * R_TO_CP, 0))
	var path_name = element.get_named_attribute_value("id") if element.has_attribute("id") else "Rect"
	create_path2d(path_name, current_node, curve,
			get_svg_transform(element), get_svg_style(element), scene_root, gradients, true,
			Vector2(x, y))


func process_svg_polygon(element:XMLParser, current_node : Node2D, scene_root : Node2D, is_closed : bool,
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
	create_path2d(path_name, current_node, curve,
			get_svg_transform(element), get_svg_style(element), scene_root, gradients, is_closed)


func process_svg_path(element:XMLParser, current_node : Node2D, scene_root : Node2D,
		gradients : Array[Dictionary]) -> void:
	# FIXME: better parsing, splits into sub arrays not necessary

	var str_path = parse_attribute_string(
				element.get_named_attribute_value("d")).replacen(",", " ")

	for symbol in ["m", "M", "v", "V", "h", "H", "l", "L", "c", "C", "s", "S", "a", "A", "q", "Q", "t", "T", "z", "Z"]:
		str_path = str_path.replace(symbol, " " + symbol + " ")

	var str_path_array = str_path.split(" ", false)
	var string_arrays = []
	var string_array_top : PackedStringArray
	for a in str_path_array:
		if a == "m" or a == "M":
			if string_array_top.size() > 0:
				string_arrays.append(string_array_top)
				string_array_top.resize(0)
		string_array_top.append(a)
	string_arrays.append(string_array_top)

	var string_array_count = -1
	for string_array in string_arrays:
		var cursor = Vector2.ZERO
		var curve = Curve2D.new()
		string_array_count += 1

		for i in string_array.size()-1:
			match string_array[i]:
				"m":
					while string_array.size() > i + 2 and string_array[i+1].is_valid_float():
						cursor += Vector2(float(string_array[i+1]), float(string_array[i+2]))
						curve.add_point(cursor)
						i += 2
				"M":
					while string_array.size() > i + 2 and string_array[i+1].is_valid_float():
						cursor = Vector2(float(string_array[i+1]), float(string_array[i+2]))
						curve.add_point(cursor)
						i += 2
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
					while string_array.size() > i + 4 and string_array[i+4].is_valid_float():
						var prev_point := curve.get_point_position(curve.get_point_count() - 1)
						var quadratic_control_point = cursor + Vector2(float(string_array[i+1]), float(string_array[i+2]))
						var c_out = (quadratic_control_point - prev_point) * (2.0/3.0)
						cursor += Vector2(float(string_array[i+3]), float(string_array[i+4]))
						var c_in = (quadratic_control_point - cursor) * (2.0/3.0)
						curve.set_point_out(curve.get_point_count() - 1, c_out)
						curve.add_point(cursor, c_in)
						i += 4
				"Q":
					while string_array.size() > i + 4 and string_array[i+4].is_valid_float():
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
					log_message("WARNING: the 'a' (relative arc) operation is not yet supported, shape for <path id=\"%s\"> will be incorrect" %
							(element.get_named_attribute_value("id") if element.has_attribute("id") else "?"), LogLevel.WARN)
					while string_array.size() > i + 7 and string_array[i+1].is_valid_float():
						cursor += Vector2(float(string_array[i+6]), float(string_array[i+7]))
						curve.add_point(cursor)
						i += 7
				"A":
					log_message("WARNING: the 'A' (absolute arc) operation is not yet supported, shape for <path id=\"%s\"> will be incorrect" %
							(element.get_named_attribute_value("id") if element.has_attribute("id") else "?"), LogLevel.WARN)
					while string_array.size() > i + 7 and string_array[i+1].is_valid_float():
						cursor = Vector2(float(string_array[i+6]), float(string_array[i+7]))
						curve.add_point(cursor)
						i += 7

		if curve.get_point_count() > 1:
			var id = element.get_named_attribute_value("id") if element.has_attribute("id") else "Path"
			create_path2d(id, current_node,  curve,
						get_svg_transform(element), get_svg_style(element), scene_root, gradients,
						string_array[string_array.size()-1].to_upper() == "Z")


func create_path2d(path_name: String, parent: Node, curve: Curve2D, transform: Transform2D,
						style: Dictionary, scene_root: Node2D, gradients : Array[Dictionary],
						is_closed := false, pos_override := Vector2.ZERO) -> void:
	var new_path = ScalableVectorShape2D.new()
	new_path.name = path_name
	new_path.position = pos_override
	new_path.curve = curve
	new_path.lock_assigned_shapes = keep_drawable_path_node and lock_shapes
	if pos_override == Vector2.ZERO:
		new_path.set_position_to_center()

	var ancestor = parent
	while !ancestor.has_meta(SVG_ROOT_META_NAME):
		style.merge(ancestor.get_meta(SVG_STYLE_META_NAME, {}))
		ancestor = ancestor.get_parent()
	var gradient_point_parent : Node2D = parent
	if transform == Transform2D.IDENTITY:
		parent.add_child(new_path, true)
	else:
		var transform_node := Node2D.new()
		transform_node.name = path_name + "Transform"
		transform_node.transform = transform
		parent.add_child(transform_node, true)
		transform_node.add_child(new_path, true)
		transform_node.set_owner(scene_root)
		gradient_point_parent = transform_node
	new_path.set_owner(scene_root)
	if style.has("opacity"):
		new_path.modulate.a = float(style["opacity"])
	if style.is_empty():
		var line := Line2D.new()
		line.name = "Stroke"
		line.antialiased = antialiased_shapes
		new_path.add_child(line, true)
		line.set_owner(scene_root)
		new_path.line = line
		line.width = 1.0
		line.closed = is_closed
	elif "fill" not in style and "stroke" not in style:
		style["fill"] = "#000000"

	if paint_order_is_normal(style):
		add_fill_to_path(new_path, style, scene_root, gradients, gradient_point_parent)
		add_stroke_to_path(new_path, style, scene_root, is_closed)
	else:
		add_stroke_to_path(new_path, style, scene_root, is_closed)
		add_fill_to_path(new_path, style, scene_root, gradients, gradient_point_parent)

	# FIXME: Apply paint-order to imported CollisionPolygon2D (treat it as a guide)
	if (import_collision_polygons and
			("fill" in style or import_collision_polygons_for_all_shapes)):
		var poly := CollisionPolygon2D.new()
		new_path.add_child(poly, true)
		poly.set_owner(scene_root)
		new_path.collision_polygon = poly

	if not keep_drawable_path_node:
		var bare_node := Node2D.new()
		bare_node.name = new_path.name
		bare_node.position = new_path.position
		new_path.replace_by(bare_node)
		new_path.queue_free()


func paint_order_is_normal(style : Dictionary) -> bool:
	if style.has("paint-order"):
		if style["paint-order"] == "normal":
			return true
		elif style["paint-order"] == "stroke":
			return false
		var parts = style["paint-order"].split(" ")
		return parts.find("stroke") > parts.find("fill")
	return true


func add_stroke_to_path(new_path : Node2D, style: Dictionary, scene_root : Node2D, is_closed: bool):
	if style.has("stroke") and style["stroke"] != "none":
		var line := Line2D.new()
		line.name = "Stroke"
		line.antialiased = antialiased_shapes
		new_path.add_child(line, true)
		line.set_owner(scene_root)
		if style["stroke"].begins_with("url"):
			log_message("⚠️ Unsupported stroke style: " + style["stroke"])
		else:
			line.default_color = Color(style["stroke"])
		if style.has("stroke-width"):
			line.width = float(style['stroke-width'])
		if style.has("stroke-opacity"):
			line.self_modulate.a = float(style["stroke-opacity"])
		new_path.line = line
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.closed = is_closed


func add_fill_to_path(new_path : ScalableVectorShape2D, style: Dictionary, scene_root : Node2D,
		gradients : Array[Dictionary], gradient_point_parent : Node2D):

	if style.has("fill") and style["fill"] != "none":
		var polygon := Polygon2D.new()
		polygon.name = "Fill"
		polygon.antialiased = antialiased_shapes
		new_path.add_child(polygon, true)
		polygon.set_owner(scene_root)
		if style["fill"].begins_with("url"):
			var href : String = style["fill"].replace("url(", "").replace(")", "")
			var svg_gradient = get_gradient_by_href(href, gradients)
			if svg_gradient.is_empty():
				log_message("⚠️ Cannot find gradient for href=%s" % href, LogLevel.WARN)
			else:
				add_gradient_to_fill(new_path, svg_gradient, polygon, scene_root, gradients, gradient_point_parent)
		else:
			polygon.color = Color(style["fill"])
		if style.has("fill-opacity"):
			polygon.self_modulate.a = float(style["fill-opacity"])
		new_path.polygon = polygon


func add_gradient_to_fill(new_path : ScalableVectorShape2D, svg_gradient: Dictionary, polygon : Polygon2D,
		scene_root : Node2D, gradients : Array[Dictionary], gradient_point_parent : Node2D) -> void:
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
		scene_root : Node2D, gradients : Array[Dictionary], gradient_point_parent : Node2D, box : Rect2,
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


func create_helper_node(node_name : String, node_parent : Node2D, node_owner : Node2D,
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


func get_svg_transform(element:XMLParser) -> Transform2D:
	if element.has_attribute("transform"):
		return process_svg_transform(element.get_named_attribute_value("transform"))
	else:
		return Transform2D.IDENTITY


func process_svg_transform(svg_transform : String) -> Transform2D:
	var transform = Transform2D.IDENTITY
	if svg_transform.begins_with("translate"):
		svg_transform = svg_transform.replace("translate", "").replacen("(", "").replacen(")", "")
		var transform_split = svg_transform.split_floats(",")
		transform[2] = Vector2(transform_split[0], transform_split[1])
	elif svg_transform.begins_with("scale"):
		svg_transform = svg_transform.replace("scale", "").replacen("(", "").replacen(")", "")
		var transform_split = svg_transform.split_floats(",")
		transform = transform.scaled(Vector2(transform_split[0], transform_split[1]))
	elif svg_transform.begins_with("rotate"):
		svg_transform = svg_transform.replace("rotate", "").replacen("(", "").replacen(")", "")
		var transform_split = svg_transform.split_floats(",")
		if transform_split.size() == 1:
			transform = transform.rotated(deg_to_rad(transform_split[0]))
		elif transform_split.size() == 3:
			transform = transform.translated(-Vector2(transform_split[1], transform_split[2]))
			transform = transform.rotated(deg_to_rad(transform_split[0]))
			transform = transform.translated(Vector2(transform_split[1], transform_split[2]))
	elif svg_transform.begins_with("matrix"):
		svg_transform = svg_transform.replace("matrix", "").replacen("(", "").replacen(")", "")
		var matrix = svg_transform.split_floats(",")
		for i in 3:
			transform[i] = Vector2(matrix[i*2], matrix[i*2+1])
	return transform


func get_svg_style(element:XMLParser) -> Dictionary:
	# FXIME: better parsing
	var style = {}
	if element.has_attribute("style"):
		var svg_style = element.get_named_attribute_value("style")
		svg_style = svg_style.rstrip(";")
		svg_style = svg_style.replacen(": ", ":")
		svg_style = svg_style.replacen(":", "\":\"")
		svg_style = svg_style.replacen("; ", "\",\"")
		svg_style = svg_style.replacen(";", "\",\"")
		svg_style = "{\"" + svg_style + "\"}"
		var json = JSON.new()
		var error = json.parse(svg_style)
		if error == OK:
			style = json.data
		else:
			log_message("Failed to parse some styles for <%s id=\"%s\">" % [element.get_node_name(),
					element.get_named_attribute_value("id") if element.has_attribute("id") else "?"],
					LogLevel.WARN)
	for style_prop in SUPPORTED_STYLES:
		if element.has_attribute(style_prop):
			style[style_prop] = element.get_named_attribute_value(style_prop)

	return style


static func parse_attribute_string(raw_attribute_str : String) -> String:
	var regex = RegEx.new()
	regex.compile("\\S+")
	var str_path = ""
	for result  in regex.search_all(raw_attribute_str):
		str_path += result.get_string() + " "
	return str_path.strip_edges()


func _on_import_collision_polygons_check_box_toggled(toggled_on: bool) -> void:
	import_collision_polygons = toggled_on
	import_collision_polygons_for_all_shapes_checkbox.visible = toggled_on


func _on_import_collision_polygons_for_all_shapes_check_box_toggled(toggled_on: bool) -> void:
	import_collision_polygons_for_all_shapes = toggled_on


func _on_keep_drawable_path_2d_node_check_box_toggled(toggled_on: bool) -> void:
	keep_drawable_path_node = toggled_on
	lock_shapes_checkbox.visible = toggled_on


func _on_lock_shapes_check_box_toggled(toggled_on: bool) -> void:
	lock_shapes = toggled_on


func _on_antialiased_check_box_toggled(toggled_on: bool) -> void:
	antialiased_shapes = toggled_on


func _on_open_file_dialog_button_pressed() -> void:
	import_file_dialog.popup_file_dialog()


func _on_enable_editing_checkbox_toggled(toggled_on: bool) -> void:
	toggle_gui_editing.emit(toggled_on)


func _on_enable_hints_checkbox_toggled(toggled_on: bool) -> void:
	toggle_gui_hints.emit(toggled_on)
