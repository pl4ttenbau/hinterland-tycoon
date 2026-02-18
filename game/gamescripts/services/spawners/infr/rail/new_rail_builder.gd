class_name NewRailBuilder extends Node

const BEDDING_OFFSET: Vector3 = Vector3(0, .2, 0)

@export var is_active: bool = false

@export var curr_track3d: RailTrack3D:
	get():
		if self.is_active:
			return UiState.build_infr_mode.track3d
		return null

#region Initialization
func _enter_tree() -> void:
	SignalBus.ui_mode_switched.connect(Callable(self, "_on_ui_mode_changed"))
	SignalBus.terrain_click.connect(Callable(self, "_on_terrain_click"))
	
func _get_next_track_num() -> int:
	return Managers.rails.track_storage._max_num +1
#endregion

#region Create Tracks
func create_new_track() -> RailTrack3D:
	# create new rail track obj
	var new_track: RailTrackData = RailTrackData.new()
	new_track.num = self._get_next_track_num()
	new_track.track_name = "New Track %d" % new_track.num
	new_track.infr_type_key = "750_MM"
	Loggie.info("Creating new track: %s" % new_track.track_name)
	# spawn as RailTrack3D
	var track3d: RailTrack3D = Managers.rails.instanciate_rail_track(new_track)
	Managers.rails.add_child(track3d)
	return track3d
#endregion

#region Extend Tracks
func add_new_node(pos: Vector3):
	if ! UiState.build_infr_mode:
		Loggie.error("Cannot extend tracks: building mode inactive")
		return
	var _curr_track: RailTrackData = self.curr_track3d.track
	var node_i: int = _curr_track.nodes.size()
	var new_node: RailNodeData = RailNodeData.of(node_i, pos, _curr_track)
	_curr_track.add_node(new_node, true)
	UiState.build_infr_mode.track3d.curve = _curr_track.curve
	Loggie.info("New Node at %v in %s" % [pos, _curr_track.track_name])
#endregion

#region Spawn & Exit

#endregion

#region Callables
func _on_ui_mode_changed(ui_mode: Enums.UiMode):
	self.is_active = ui_mode == Enums.UiMode.BUILD_INFR
	if self.is_active:
		UiState.build_infr_mode.track3d = self.create_new_track()
		# add starting pos to track
		self.add_new_node(UiState.build_infr_mode.at_fork.pos)
	
func _on_terrain_click(pos: Vector3):
	if ! self.is_active: return
	var bedding_pos: Vector3 = pos + BEDDING_OFFSET
	self.add_new_node(bedding_pos)
#endregion
