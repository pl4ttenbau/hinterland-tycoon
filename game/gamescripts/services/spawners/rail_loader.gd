@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailsLoader extends Node

const MAP_RAILS_FILEPATH_FORMAT := "res://world/%s/jsondata/tracks.json"
const RAILS_INFR_GROUP := "Rails"
const MAX_VISIBLE_DIST := 300

@export var tracks: Array[RailTrackData] = []
@export var track_containers: Array[OuterRailTrack] = []

@export var tracks_by_num: Dictionary = {}

func _enter_tree() -> void:
	Managers.rails = self
	SignalBus.world_update.connect(Callable(self, "_on_world_update"))
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))
	
func _ready() -> void:
	load_rail_tracks()
	Loggie.info("rails precreated")

func load_rail_tracks() -> void:
	var rail_file_path := MAP_RAILS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var rails_arr_str: String = FileAccess.get_file_as_string(rail_file_path)
	for json_track in JSON.parse_string(rails_arr_str):
		var track_obj := RailTrackData.from_json(json_track)
		self.tracks.append(track_obj)
		var track_num_str = "%d" % track_obj.num
		self.tracks_by_num.set(track_num_str, track_obj)
	# add to holding arrays
	GlobalState.tracks = self.tracks
	# trigger signal
	SignalBus.rails_loaded.emit(self.tracks)

#region RailTrack Spawning
func spawn_rails():
	for track_obj: RailTrackData in GlobalState.tracks:
		self.spawn_rail_track(track_obj)
		self.spawn_rail_forks(track_obj)
	# emit signals
	SignalBus.rails_spawned.emit(track_containers)
	
func instanciate_rail_track(rail_track: RailTrackData) -> OuterRailTrack:
	if ! rail_track.curve: rail_track.build_path()
	# instanciate Container from PackedScene
	var scene_path = OuterRailTrack.get_scene_path(rail_track)
	var outer_track: OuterRailTrack = load(scene_path).instantiate()
	outer_track.track = rail_track
	GlobalState.outer_tracks.append(outer_track)
	return outer_track
	
func spawn_rail_track(track_obj: RailTrackData):
	var outer_track := self.instanciate_rail_track(track_obj)
	add_child(outer_track, true)
	self.track_containers.append(outer_track)
	# emit
	SignalBus.rail_spawned.emit(outer_track)
	
func spawn_rail_forks(parent_track: RailTrackData):
	for fork: RailForkData in parent_track.forks:
		fork.spawn()
		fork.container.adjust_rotation()
#endregion

#region Event Listeners
func _on_map_spawned(_container: TerrainContainer):
	self.spawn_rails()
	
func _on_world_update() -> void:
	for container: OuterRailTrack in self.track_containers:
		var player: Node3D = %Player
		if player:
			var middle_pos: Vector3 = container.get_middle_pos()
			var dist = self._get_cam_pos().distance_to(middle_pos)
			if dist > MAX_VISIBLE_DIST: container.visible = false
			else: container.visible = true
#endregion

#region Helper-Methods
func _get_cam_pos() -> Vector3:
	if GlobalState.active_cam != null:
		return GlobalState.active_cam.global_position
	return GlobalState.player.global_position
#endregion
