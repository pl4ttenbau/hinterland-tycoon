@icon("res://assets/icons/icon_fork.png")
class_name OuterRailFork extends VisibleObject

const NINETY_DEG_IN_RAD = 1.57

@export var fork_obj: RailForkData:
	get(): return self.entity as RailForkData
	set(value): self.entity = value

static func of(_fork: RailForkData) -> OuterRailFork:
	var inst := OuterRailFork.new()
	inst.entity = _fork
	return inst
	
func _enter_tree() -> void:
	self.fork_obj.set_to_changed.connect(Callable(self, "_on_set_to_changed"))
	
func _ready() -> void:
	self._on_set_to_changed(self.fork_obj.set_to)

func adjust_rotation() -> void:
	var rot_target_node: RailNodeData = null
	if self.is_at_end(): rot_target_node = self.entity.railNode.get_previous()
	else: rot_target_node = self.entity.railNode.get_next()
	if rot_target_node && rot_target_node.position:
		self.look_at(rot_target_node.position)
		self.rotate_y(NINETY_DEG_IN_RAD)

#region Callbacks
func _on_set_to_changed(track_num: int):
	$ForkLabel.text = str(track_num)
#endregion

#region Helper-Methods
func is_at_end() -> bool: return self.entity.railNode.is_last()

func is_at_start() -> bool: return self.entity.railNode.is_first()
#endregion
