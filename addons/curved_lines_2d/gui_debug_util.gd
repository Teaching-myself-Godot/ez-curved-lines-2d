@tool
extends Object

class_name GUIDebugUtil

## Will print the tree (use with care, because your plugin will probably not be forward compatible across versions)
static func dump_interface(n : Node, max_d : int = 2, d : int = 0) -> void:
	if n.name.contains("Dialog") or n.name.contains("Popup"):
		return
	print(n.name.lpad(d + n.name.length(), "-") + " (%d)" % [n.get_child_count()])
	for c in n.get_children():
		if d < max_d:
			dump_interface(c, max_d, d + 1)
