class_name RailBuffer3D extends VisibleObject

const NINETY_DEG_IN_RAD = 1.57

@export var parent_node: RailNodeData:
	get(): return parent_node
	set(value):
		parent_node = value
		self.position = value.position
		self.adjust_rotation()

func adjust_rotation():
	if ! self.parent_node:
		Loggie.error("Cannot spawn track vuffer correctly: not connected to rail node!")
	var rot_target_node: RailNodeData = null
	if self.is_at_end():
		rot_target_node = self.parent_node.get_previous()
	else: 
		rot_target_node = self.parent_node.get_next()
	if rot_target_node && rot_target_node.position:
		self.look_at_from_position(self.position, rot_target_node.position)

func is_at_end() -> bool: return self.parent_node.is_last()

func is_at_start() -> bool: return self.parent_node.is_first()
