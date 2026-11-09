class_name GreasePencilAnimationImporter extends Object

static func detect_animation(xml : SVGXMLElement) -> bool:
	if xml.get_named_attribute_value_safe("id") == "blender_animation":
		return true
	for ch in xml.children:
		if detect_animation(ch):
			return true
	return false
