@tool
extends Object

class_name SVGXMLElement

const SUPPORTED_STYLES : Array[String] = ["opacity", "stroke", "stroke-width", "stroke-opacity",
		"fill", "fill-opacity", "paint-order", "stroke-linecap", "stroke-linejoin",
		"stroke-miterlimit", "clip-path"]

var name : String
var attributes : Dictionary[String, String]
var children : Array[SVGXMLElement]
var parent : SVGXMLElement

func _init(xml_parser : XMLParser, with_parent : SVGXMLElement = null):
	name = xml_parser.get_node_name()
	for i in xml_parser.get_attribute_count():
		attributes[xml_parser.get_attribute_name(i)] = xml_parser.get_attribute_value(i)
	parent = with_parent

func add_child(ch : SVGXMLElement) -> void:
	children.append(ch)


func has_attribute(x : String) -> bool:
	return x in attributes


func get_named_attribute_value(x : String) -> String:
	if x in attributes:
		return attributes[x]
	printerr("WARNING: element <%s> does not have %s" % [name, x])
	return ""


func get_node_name() -> String:
	return name


func get_named_attribute_value_safe(x : String) -> String:
	if x in attributes:
		return attributes[x]
	return ""


func find_by_id(id : String) -> SVGXMLElement:
	var ancestor = self
	while ancestor.parent != null:
		ancestor = ancestor.parent
	return find_child_by_id(id, ancestor)


func find_child_by_id(id : String, n := self) -> SVGXMLElement:
	if "id" in n.attributes and n.attributes["id"] == id:
		return n
	for nn in n.children:
		var result := find_child_by_id(id, nn)
		if result:
			return result
	return null



func is_empty() -> bool:
	return children.is_empty()


func _to_string() -> String:
	var attrs := PackedStringArray(attributes.keys().map(func(k): return k + "=\"" + attributes[k] + "\""))
	var ch := PackedStringArray(children.map(str))
	if children.is_empty():
		return "<" + name + " " + " ".join(attrs) + " />"
	else:
		return "<" + name + " " + " ".join(attrs) + ">" + "\n".join(ch) + "</" + name + ">"


func get_svg_style(log_message : Callable) -> Dictionary:
	var style = {}
	if has_attribute("style"):
		var svg_style = get_named_attribute_value("style")
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
			log_message.call("Failed to parse some styles for <%s id=\"%s\">" % [name,
					get_named_attribute_value("id") if has_attribute("id") else "?"], 2)
	for style_prop in SUPPORTED_STYLES:
		if has_attribute(style_prop):
			style[style_prop] = get_named_attribute_value(style_prop)
	return style


func get_merged_styles(log_message : Callable) -> Dictionary:
	var style = get_svg_style(log_message)
	var ancestor = self
	while ancestor.parent != null:
		style.merge(ancestor.get_svg_style(log_message))
		ancestor = ancestor.parent
	style.merge(ancestor.get_svg_style(log_message))
	return style
