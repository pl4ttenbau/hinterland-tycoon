class_name ShowNearInfrAction extends Node

const MARKER_SCENE = "res://assets/meshes/markers/infr_end/selected_node.tscn"

func on_trigger():
	var player_pos: Vector3 = GlobalState.player.global_position
	var near_tracks: Array[RailTrackData] = self.get_tracks_near_pos(player_pos)
	Loggie.info("Near tracks: " + ", ".join(near_tracks))
	var nearest_fork: NewRailForkData = get_nearest_fork(player_pos, near_tracks)
	if nearest_fork:
		var nearest_track_name: String = nearest_fork.rail_nodes[0].parent_track.track_name
		Loggie.info("Nearest fork: Node %d of Track \"%s\"" % [nearest_fork.num, nearest_track_name])
		self.spawn_fork_marker(nearest_fork)
	else:
		Loggie.warn("No near railway tracks found of %d" % self.count_tracks())
	
func get_tracks_near_pos(pos: Vector3) -> Array[RailTrackData]:
	var result_arr: Array[RailTrackData] = []
	for track_data in Managers.rails.track_storage.get_all():
		if track_data.is_near(pos):
			result_arr.append(track_data)
	return result_arr

func get_nearest_fork(pos: Vector3, near_tracks: Array[RailTrackData]) -> NewRailForkData:
	var nearest_fork: NewRailForkData
	var nearest_fork_dist: float
	for near_track in near_tracks:
		for node_fork in near_track.get_node_forks():
			var fork_dist: float = node_fork.position.distance_squared_to(pos)
			if ! nearest_fork_dist || fork_dist < nearest_fork_dist:
				nearest_fork_dist = fork_dist
				nearest_fork = Managers.forks.get_fork_at_pos(node_fork.position)
	return nearest_fork
	
func count_tracks() -> int:
	return Managers.rails.track_storage.get_all().size()
	
func spawn_fork_marker(_fork: NewRailForkData):
	self.enable_building_mode()
	var marker: SelectedNodeMarker3D = load(MARKER_SCENE).instantiate()
	_fork.container.add_child(marker)

func enable_building_mode():
	UiState.ui_mode = Enums.UiMode.BUILD_INFR
	SignalBus.ui_mode_switched.emit(Enums.UiMode.BUILD_INFR)
