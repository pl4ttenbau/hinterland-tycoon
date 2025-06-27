class_name OuterRailFork extends HideableObject

static func of(_fork: RailForkData) -> OuterRailFork:
	var inst := OuterRailFork.new()
	inst.entity = _fork
	return inst

func is_at_end() -> bool:
	return self.entity.railNode.is_last()

func is_at_start() -> bool:
	return self.entity.railNode.is_first()

func adjust_rotation() -> void:
	var rot_target_node: RailNodeData = null
	if self.is_at_end():
		rot_target_node = self.entity.railNode.get_previous()
	else:
		rot_target_node = self.entity.railNode.get_next()
	self.look_at(rot_target_node.position)
