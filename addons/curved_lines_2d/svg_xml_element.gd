@tool
extends Object

class_name SVGXMLElement

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


func is_empty() -> bool:
	return children.is_empty()


func _to_string() -> String:
	var attrs := PackedStringArray(attributes.keys().map(func(k): return k + "=\"" + attributes[k] + "\""))
	var ch := PackedStringArray(children.map(str))
	if children.is_empty():
		return "<" + name + " " + " ".join(attrs) + " />"
	else:
		return "<" + name + " " + " ".join(attrs) + ">" + "\n".join(ch) + "</" + name + ">"
