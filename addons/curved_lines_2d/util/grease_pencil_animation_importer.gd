class_name GreasePencilAnimationImporter extends Object

static func detect_animation(xml : SVGXMLElement) -> bool:
	if xml.get_named_attribute_value_safe("id") == "blender_animation":
		return true
	for ch in xml.children:
		if detect_animation(ch):
			return true
	return false


static func get_blender_frames_xml(xml : SVGXMLElement) -> Array[SVGXMLElement]:
	var fr_root := xml.find_by_id("blender_frames")
	if not fr_root:
		return []

	var result : Array[SVGXMLElement] = []
	var clip_paths : Array[SVGXMLElement] = []
	for cp in fr_root.children.filter(func(n): return n.name == "clipPath"):
		clip_paths.append(cp)
	var i := 0
	for fr : SVGXMLElement in fr_root.children.filter(func(n): return n.name == "g"):
		var rt := SVGXMLElement.new()
		rt.name = xml.name
		rt.attributes = xml.attributes.duplicate(true)
		rt.attributes["frame_id"] = fr.get_named_attribute_value_safe("id")
		if fr.get_named_attribute_value_safe("clip-path"):
			rt.add_child(xml.find_by_id(fr.get_named_attribute_value_safe("clip-path").replace("url(#", "").replace(")", "")))
		rt.add_child(fr)
		result.append(rt)
		i += 1
	return result
