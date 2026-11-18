class_name GreasePencilAnimationImporter extends Object

static func detect_animation(xml : SVGXMLElement) -> bool:
	if not Engine.is_editor_hint():
		return false

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
			rt.add_child(xml.find_by_id(fr.get_named_attribute_value_safe("clip-path").replace("#", "").replace("url(", "").replace(")", "")))
		rt.add_child(fr)
		result.append(rt)
		i += 1
	return result


static func import_blender_svg(svg_importer : SVGImporter, svg_xml_node : SVGXMLElement, file_path : String) -> Node:
	var scene_root := EditorInterface.get_edited_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	svg_importer.undo_redo = SVGImporter.get_runtime_handler()
	ur.create_action("Import Grease Pencil SVG animation")
	var blender_frames := GreasePencilAnimationImporter.get_blender_frames_xml(svg_xml_node)
	var animation := Animation.new()
	var use_node := svg_xml_node.find_by_id("blender_animation")
	var anim_node := svg_xml_node.find_by_node_name("animate")
	var start_frame_id := use_node.get_named_attribute_value_safe("href").replace("#", "").strip_edges()
	animation.length = float(anim_node.get_named_attribute_value_safe("dur"))
	if anim_node.get_named_attribute_value_safe("repeatCount") == "indefinite":
		animation.loop_mode = Animation.LOOP_LINEAR
	var frame_nodes : Dictionary[String, Node2D] = {}
	var frame_dir_name := file_path.get_file().replace(".svg", "").to_snake_case()
	svg_importer.import_as_svs = false
	DirAccess.make_dir_absolute("res://" + frame_dir_name)

	for fr in blender_frames:
		var src := await svg_importer.parse_svg_xml_to_nodes(fr,
				"BlenderFrame",
				scene_root, scene_root, [],
				false
		)
		var cpy := src.duplicate()
		cpy.owner = null
		for node in cpy.get_children():
			svg_importer._recursive_set_owner_direct(node, cpy)
		var scene := PackedScene.new()
		scene.pack(cpy)
		ResourceSaver.save(scene, "res://%s/%s.scn" % [
			frame_dir_name,
			fr.get_named_attribute_value_safe("frame_id")], ResourceSaver.FLAG_NONE)
		scene_root.remove_child(src)
		src.free()
		scene = ResourceLoader.load("res://%s/%s.scn" % [
			frame_dir_name,
			fr.get_named_attribute_value_safe("frame_id")])
		var imported_scene : Node2D = scene.instantiate()
		if fr.get_named_attribute_value_safe("frame_id") != start_frame_id:
			imported_scene.visible = false
		ur.add_do_method(scene_root, "add_child", imported_scene, true)
		ur.add_do_property(imported_scene, "owner", scene_root)
		ur.add_undo_method(scene_root, "remove_child", imported_scene)
		ur.add_undo_reference(imported_scene)
		frame_nodes[fr.get_named_attribute_value_safe("frame_id")] = imported_scene
	var animation_player := AnimationPlayer.new()
	animation_player.add_animation_library("", AnimationLibrary.new())
	animation_player.get_animation_library("").add_animation("grease_pencil_import", animation)
	animation_player.autoplay = "grease_pencil_import"
	ur.add_do_method(scene_root, 'add_child', animation_player, true)
	ur.add_do_property(animation_player, 'owner', scene_root)
	ur.add_undo_method(scene_root, 'remove_child', animation_player)
	ur.add_undo_reference(animation_player)
	ur.commit_action()

	var anim_frames := anim_node.get_named_attribute_value_safe("values").replace("#", "").split(";", false)
	var step := animation.length / float(anim_frames.size())
	var pos := 0.0
	for frame_id in anim_frames:
		var node := frame_nodes[frame_id]
		var track_idx := add_anim_track_if_absent(animation, "%s:%s" % [
				scene_root.get_path_to(node), "visible"])
		animation.track_insert_key(track_idx, 0.0, frame_id == start_frame_id)
		if frame_id != start_frame_id:
			animation.track_insert_key(track_idx, pos, true)
		animation.track_insert_key(track_idx, pos + step, false)
		pos += step
	return scene_root


static func add_anim_track_if_absent(animation : Animation, node_path : NodePath) -> int:
	var t_idx := animation.find_track(node_path, Animation.TrackType.TYPE_VALUE)
	if t_idx < 0:
		t_idx = animation.add_track(Animation.TrackType.TYPE_VALUE)
		animation.track_set_path(t_idx, node_path)
		animation.value_track_set_update_mode(t_idx, Animation.UPDATE_DISCRETE)
	return t_idx
