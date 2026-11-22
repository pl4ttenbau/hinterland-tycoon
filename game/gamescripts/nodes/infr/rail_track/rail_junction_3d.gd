@icon("res://assets/icons/nodes_3d/icon_fork.svg")
class_name RailJunction3D extends GameEntity3D

signal fork_obj_set(set_fork_obj: RailJunctionData)

@export var fork_obj: RailJunctionData:
	get(): return self.entity as RailJunctionData
	set(value): 
		self.entity = value
		fork_obj_set.emit(value)

@export var fork_mesh: MeshInstance3D
@export var fork_arrow_mesh: MeshInstance3D

#region Initializations
func _init() -> void:
	self.fork_obj_set.connect(Callable(self, "_on_fork_obj_set"))
#endregion

func adjust_rotation() -> void:
	if not is_inside_tree() or fork_obj.connected_tracks.is_empty():
		return
	var next_static_node_pos: Vector3 = self._get_pos_of_next_static_track_node()
	self.look_at(next_static_node_pos)
	self.rotate_y(GameConstants.NINETY_DEG_IN_RAD)
	# reset arrow rotation back to initial
	self.adjust_fork_arrow_rotation()

func adjust_fork_arrow_rotation():
	if self.fork_obj.setting.current == null:
		return
	var target: Vector3 = self.fork_obj.setting.get_connected_next_node().position
	$ForkArrow.look_at(target)

func _get_pos_of_next_static_track_node() -> Vector3:
	var static_track_num: int = self.fork_obj.get_static_track_num()
	var static_track: RailTrackData = Managers.rails.track_storage.get_by_num(static_track_num)
	var dir_from_static: Enums.PathDirection = self.fork_obj.get_track_dir_from_fork(static_track_num)
	# find index of next static track node
	var next_static_node_i: int = -1
	if dir_from_static == Enums.PathDirection.TRACK_NODES_INCREASE:
		next_static_node_i = 1
	else:
		next_static_node_i = static_track.nodes.size() -2
	# return pos of node with index
	return static_track.get_rail_node(next_static_node_i).position

#region Callbacks
func _on_fork_obj_set(set_fork_obj: RailJunctionData):
	# rename
	self.name = "Fork3D_%d_%d" % [set_fork_obj.num, set_fork_obj.connected_tracks[0]]
	# set pos
	self.position = set_fork_obj.pos
	# connect so signals
	set_fork_obj.switched.connect(Callable(self, "_on_fork_switched"))
	set_fork_obj.setting_initialized.connect(Callable(self, "_on_setting_initialized"))

func _on_setting_initialized(_fork_setting: RailJunctionSetting):
	var can_switch: bool = self.fork_obj.setting.settable_tracks.size() > 1
	self.fork_mesh.visible = can_switch
	self.fork_arrow_mesh.visible = can_switch
	if can_switch:
		self.adjust_fork_arrow_rotation()

func _on_fork_switched(new_setting: CurrentJunctionSetting):
	if new_setting != null:
		self.adjust_fork_arrow_rotation()
#endregion
