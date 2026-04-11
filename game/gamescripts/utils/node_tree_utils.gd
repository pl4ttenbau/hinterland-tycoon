## search by type, get children recursively, etc 
class_name NodeTreeUtils extends RefCounted

static func get_all_children(node: Node) -> Array:
	var all_children : Array = []
	for direct_child in node.get_children():
		if direct_child.get_child_count() > 0:
			all_children.append(direct_child)
			all_children.append_array(get_all_children(direct_child))
		else:
			all_children.append(direct_child)
	return all_children
