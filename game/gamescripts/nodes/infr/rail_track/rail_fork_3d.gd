@icon("res://assets/icons/icon_fork.png")
class_name RailFork3D extends VisibleObject

const NINETY_DEG_IN_RAD = 1.57

@export var fork_obj: NewRailForkData:
	get(): return self.entity as NewRailForkData
	set(value): self.entity = value

static func of(_fork: NewRailForkData) -> RailFork3D:
	var inst := RailFork3D.new()
	inst.entity = _fork
	return inst
	
func _enter_tree() -> void:
	self.fork_obj.switched.connect(Callable(self, "_on_set_to_changed"))
	
func _ready() -> void:
	# self._on_set_to_changed(self.fork_obj.setting.current)
	pass

func adjust_rotation() -> void:
	pass
	#var rot_target_node: RailNodeData = null
	#if self.is_at_end(): rot_target_node = self.fork_obj.railNode.get_previous()
	#else: rot_target_node = self.entity.railNode.get_next()
	#if rot_target_node && rot_target_node.position:
		#self.look_at(rot_target_node.position)
		#self.rotate_y(NINETY_DEG_IN_RAD)

#region Callbacks
func _on_set_to_changed(new_setting: CurrentForkSetting):
	if !new_setting || !new_setting.connected: return
	$ForkLabel.text = str(new_setting.connected)
	#show arrow
	var target: Vector3 = self.fork_obj.setting.get_connected_next_node().position
	$ForkArrow.look_at(target)
	$ForkArrow.visible = true
#endregion

#region Helper-Methods
func is_at_end() -> bool: 
	var first_connected = self.fork_obj.connected_tracks[0] 
	var first_connected_track: RailTrackData = RailTrackData.get_by_num(first_connected)
	var last_node_pos: Vector3 = first_connected_track.get_end_node().position
	return self.fork_obj.pos == last_node_pos

func is_at_start() -> bool: return ! self.is_at_end()
#endregion
