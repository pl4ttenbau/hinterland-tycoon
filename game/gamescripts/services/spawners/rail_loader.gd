@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailsLoader extends Node

const MAP_RAILS_FILEPATH := "res://world/demmin/jsondata/tracks.json"
const RAILS_INFR_GROUP := "Rails"
const MAX_VISIBLE_DIST := 500

@export var tracks: Array[RailTrackData] = []
@export var track_containers: Array[OuterRailTrack] = []

signal rails_loaded(_rails: Array[RailTrackData])
signal rails_spawned(_rails: Array[OuterRailTrack])

func _enter_tree() -> void:
	Managers.rails = self
	SignalBus.scene_root_ready.connect(Callable(self, "_on_scene_ready"))
	SignalBus.world_update.connect(Callable(self, "_on_world_update"))

func load_rail_tracks() -> void:
	var rails_arr_str: String = FileAccess.get_file_as_string(MAP_RAILS_FILEPATH)
	for json_track in JSON.parse_string(rails_arr_str):
		self.tracks.append(RailTrackData.from_json(json_track))
	GlobalState.tracks = self.tracks
	self.rails_loaded.emit(self.tracks)
	
func spawn_rails():
	for track_obj: RailTrackData in GlobalState.tracks:
		self.spawn_rail_track(track_obj)
		self.spawn_rail_forks(track_obj)
	# emit signals
	self.rails_spawned.emit(track_containers)
	SignalBus.rails_spawned.emit(track_containers)
	
func instanciate_rail_track(rail_track: RailTrackData) -> OuterRailTrack:
	if ! rail_track.curve: rail_track.build_path()
	# instanciate Container from PackedScene
	var outer_track: OuterRailTrack = preload(OuterRailTrack.SCENE_PATH).instantiate()
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
		
func _ready() -> void:
	load_rail_tracks()
	spawn_rails()
	Loggie.info("rails precreated")

# == EVENT LISTENERS ==
func _on_scene_ready() -> void:
	pass
	
func _on_world_update() -> void:
	for container: OuterRailTrack in self.track_containers:
		var player: Node3D = %Player
		if player:
			var middle_pos: Vector3 = container.get_middle_pos()
			var dist = player.position.distance_to(middle_pos)
			if dist > MAX_VISIBLE_DIST:
				container.visible = false
			else:
				container.visible = true
