class_name GreasePencilAnimationImporter extends Object

const BLENDER_ANIM_ROOT_META_NAME := "blender_anim_root"
const BLENDER_ANIM_NODE_META_NAME := "blender_anim_node"

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


static func import_blender_svg(svg_importer : SVGImporter, svg_xml_node : SVGXMLElement, file_path : String,
			resource_dir : String, animation_name : String) -> Node:
	svg_importer.undo_redo = SVGImporter.get_runtime_handler()
	if animation_name.is_empty():
		animation_name = "grease_pencil_import"
	var scene_root := EditorInterface.get_edited_scene_root()
	var blender_frames := GreasePencilAnimationImporter.get_blender_frames_xml(svg_xml_node)
	var use_node := svg_xml_node.find_by_id("blender_animation")
	var anim_node := svg_xml_node.find_by_node_name("animate")
	var start_frame_id := use_node.get_named_attribute_value_safe("href").replace("#", "").strip_edges()
	var frame_nodes : Dictionary[String, Node2D] = {}
	svg_importer.import_as_svs = false

	if not DirAccess.dir_exists_absolute(resource_dir):
		var error := DirAccess.make_dir_recursive_absolute(resource_dir)
		if error != OK:
			push_error(error)
		EditorInterface.get_resource_filesystem().scan()

	var ur := NonCommittalUndoRedo.new()
	ur.create_action("Import Grease Pencil SVG animation")
	var anim_root : Node2D = scene_root.get_children().filter(
			func(n): return n is Node2D and n.has_meta(BLENDER_ANIM_ROOT_META_NAME)
		).pop_back()
	if not is_instance_valid(anim_root):
		anim_root = Node2D.new()
		anim_root.name = "AnimationRoot"
		anim_root.set_meta(BLENDER_ANIM_ROOT_META_NAME, true)
		ur.add_do_method(scene_root, 'add_child', anim_root, true)
		ur.add_do_property(anim_root, 'owner', scene_root)
		ur.add_undo_method(scene_root, 'remove_child', anim_root)
		ur.add_undo_reference(anim_root)
	var parent := Node2D.new()
	parent.name = animation_name.to_pascal_case()
	parent.set_meta(BLENDER_ANIM_NODE_META_NAME, true)
	ur.add_do_method(anim_root, 'add_child', parent, true)
	ur.add_do_property(parent, 'owner', scene_root)
	ur.add_undo_method(anim_root, 'remove_child', parent)
	ur.add_undo_reference(parent)

	var cnt : int = 0
	for fr in blender_frames:
		cnt += 1
		var src := await svg_importer.parse_svg_xml_to_nodes(fr,
				animation_name.to_pascal_case(),
				scene_root, scene_root, [],
				false
		)
		var cpy := src.duplicate()
		cpy.owner = null
		cpy.name = "BlenderFrame%d" % cnt
		for node in cpy.get_children():
			svg_importer._recursive_set_owner_direct(node, cpy)
		var scene := PackedScene.new()
		scene.pack(cpy)
		ResourceSaver.save(scene, "%s/%s.scn" % [
			resource_dir.rstrip("/"),
			fr.get_named_attribute_value_safe("frame_id")], ResourceSaver.FLAG_NONE)
		scene_root.remove_child(src)
		src.free()
		scene = ResourceLoader.load("%s/%s.scn" % [
			resource_dir.rstrip("/"),
			fr.get_named_attribute_value_safe("frame_id")])
		var imported_scene : Node2D = scene.instantiate()
		if fr.get_named_attribute_value_safe("frame_id") != start_frame_id:
			imported_scene.visible = false
		ur.add_do_method(parent, "add_child", imported_scene, true)
		ur.add_do_property(imported_scene, "owner", scene_root)
		ur.add_undo_method(parent, "remove_child", imported_scene)
		ur.add_undo_reference(imported_scene)
		frame_nodes[fr.get_named_attribute_value_safe("frame_id")] = imported_scene

	var animation_player := scene_root.get_children().filter(func(n):
		return n is AnimationPlayer and n.has_meta(BLENDER_ANIM_ROOT_META_NAME)).pop_back()
	if not is_instance_valid(animation_player):
		animation_player = AnimationPlayer.new()
		animation_player.set_meta(BLENDER_ANIM_ROOT_META_NAME, true)
		animation_player.add_animation_library("", AnimationLibrary.new())
		animation_player.autoplay = animation_name
		animation_player.deterministic = true
		ur.add_do_method(scene_root, 'add_child', animation_player, true)
		ur.add_do_property(animation_player, 'owner', scene_root)
		ur.add_undo_method(scene_root, 'remove_child', animation_player)
		ur.add_undo_reference(animation_player)

	var anim_lib : AnimationLibrary = animation_player.get_animation_library("")
	var animation := Animation.new()
	animation.length = float(anim_node.get_named_attribute_value_safe("dur"))
	if anim_node.get_named_attribute_value_safe("repeatCount") == "indefinite":
		animation.loop_mode = Animation.LOOP_LINEAR
	ur.add_do_method(anim_lib, 'add_animation', animation_name, animation)
	ur.add_undo_method(anim_lib, 'remove_animation', animation_name)
	ur.commit_action()

	var anim_frames := anim_node.get_named_attribute_value_safe("values").replace("#", "").split(";", false)
	var step := animation.length / float(anim_frames.size())
	var pos := 0.0

	var track_index := add_anim_track_if_absent(animation, "%s:%s" % [
			scene_root.get_path_to(parent), "visible"])
	animation.track_insert_key(track_index, 0.0, true)

	for frame_id in anim_frames:
		var node := frame_nodes[frame_id]
		var track_idx := add_anim_track_if_absent(animation, "%s:%s" % [
				scene_root.get_path_to(node), "visible"])
		animation.track_insert_key(track_idx, 0.0, frame_id == start_frame_id)
		if frame_id != start_frame_id:
			animation.track_insert_key(track_idx, pos, true)
		animation.track_insert_key(track_idx, pos + step, false)
		if frame_id == start_frame_id:
			animation.track_insert_key(track_idx, animation.length - step, false)
		else:
			animation.track_insert_key(track_idx, pos - step, false)
		pos += step

	return animation_player


static func add_anim_track_if_absent(animation : Animation, node_path : NodePath) -> int:
	var t_idx := animation.find_track(node_path, Animation.TrackType.TYPE_VALUE)
	if t_idx < 0:
		t_idx = animation.add_track(Animation.TrackType.TYPE_VALUE)
		animation.track_set_path(t_idx, node_path)
		animation.value_track_set_update_mode(t_idx, Animation.UPDATE_DISCRETE)
	return t_idx




class NonCommittalUndoRedo extends SVGImporter.UndoRedoHandler:
	var undo_redo : EditorUndoRedoManager
	func _init() -> void:
		undo_redo = EditorInterface.get_editor_undo_redo()

	func add_do_method(thing : Object, meth : String,
				arg0 : Variant = null, arg1 : Variant = null, arg2 : Variant = null, arg3 : Variant = null) -> void:
		super.add_do_method(thing, meth, arg0, arg1, arg2, arg3)
		if arg3 != null:
			undo_redo.add_do_method(thing, meth, arg0, arg1, arg2, arg3)
		elif arg2 != null:
			undo_redo.add_do_method(thing, meth, arg0, arg1, arg2)
		elif arg1 != null:
			undo_redo.add_do_method(thing, meth, arg0, arg1)
		elif arg0 != null:
			undo_redo.add_do_method(thing, meth, arg0)
		else:
			undo_redo.add_do_method(thing, meth)


	func add_undo_method(thing : Object, meth : String,
				arg0 : Variant = null, arg1 : Variant = null, arg2 : Variant = null, arg3 : Variant = null) -> void:
		if arg3 != null:
			undo_redo.add_undo_method(thing, meth, arg0, arg1, arg2, arg3)
		elif arg2 != null:
			undo_redo.add_undo_method(thing, meth, arg0, arg1, arg2)
		elif arg1 != null:
			undo_redo.add_undo_method(thing, meth, arg0, arg1)
		elif arg0 != null:
			undo_redo.add_undo_method(thing, meth, arg0)
		else:
			undo_redo.add_undo_method(thing, meth)


	func add_do_property(thing : Object, prop_name : String, prop_value : Variant) -> void:
		thing[prop_name] = prop_value
		undo_redo.add_do_property(thing, prop_name, prop_value)


	func add_undo_property(thing : Object, prop_name : String, prop_value : Variant) -> void:
		undo_redo.add_undo_property(thing, prop_name, prop_value)


	func add_do_reference(thing : Object) -> void:
		undo_redo.add_do_reference(thing)


	func create_action(action_name : String) -> void:
		undo_redo.create_action(action_name)


	func commit_action(_apply : bool = false) -> void:
		undo_redo.commit_action(false)


	func add_undo_reference(thing : Object) -> void:
		undo_redo.add_undo_reference(thing)

