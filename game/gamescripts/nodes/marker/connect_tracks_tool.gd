## Marks the rail junction nearest to the player and switches to infrastructure
## build mode from there. Started from the build picker.
class_name ConnectTracksTool extends RefCounted

const MARKER_SCENE = "res://assets/meshes/markers/infr_end/selected_node.tscn"


static func start() -> bool:
	var player := GlobalState.player
	if not is_instance_valid(player) or not is_instance_valid(Managers.rails):
		return false
	var player_pos := player.walking_camera.global_position
	var near_tracks: Array[RailTrackData] = tracks_near(player_pos)
	Loggie.info("Near tracks: %d" % near_tracks.size())
	var nearest_fork: NewRailForkData = nearest_fork(player_pos, near_tracks)
	if nearest_fork == null:
		Loggie.warn("No near railway tracks found of %d" % Managers.rails.track_storage.get_all().size())
		return true
	var nearest_track_name: String = nearest_fork.node_forks[0].track.track_name
	Loggie.info("Nearest fork: Node %d of Track \"%s\"" % [nearest_fork.num, nearest_track_name])
	_enable_building_mode(nearest_fork)
	var marker: SelectedNodeMarker3D = load(MARKER_SCENE).instantiate()
	nearest_fork.fork3d.add_child(marker)
	return true


static func tracks_near(pos: Vector3) -> Array[RailTrackData]:
	var result: Array[RailTrackData] = []
	for track_data in Managers.rails.track_storage.get_all():
		if track_data.is_near(pos):
			result.append(track_data)
	return result


static func nearest_fork(pos: Vector3, near_tracks: Array[RailTrackData]) -> NewRailForkData:
	var nearest: NewRailForkData
	var nearest_dist: float = INF
	for near_track in near_tracks:
		for node_fork in near_track.get_node_forks():
			var fork_dist: float = node_fork.position.distance_squared_to(pos)
			if fork_dist < nearest_dist:
				nearest_dist = fork_dist
				nearest = node_fork.junction
	return nearest


static func _enable_building_mode(fork: NewRailForkData) -> void:
	UiState.build_infr_mode = UiModeBuildInfr.from_fork(fork)
	UiState.ui_mode = Enums.UiMode.BUILD_INFR
	SignalBus.ui_mode_switched.emit(Enums.UiMode.BUILD_INFR)
