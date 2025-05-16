class_name RailsLoader extends Node3D

const rails_json_path = "res://world/jsondata/tracks.json"

@onready var rails = %Rails
@onready var terrain_container: TerrainContainer = %TerrainContainer
@export var tracks: Array[RailTrack] = []
@export var track_containers: Array[OuterRailTrack] = []

signal rails_loaded(_rails: Array[RailTrack])
signal rails_spawned(_rails: Array[OuterRailTrack])

func load_rail_tracks() -> void:
	var rails_arr_str: String = FileAccess.get_file_as_string(rails_json_path)
	for json_track in JSON.parse_string(rails_arr_str):
		self.tracks.append(RailTrack.from_json(json_track))
	GlobalState.tracks = self.tracks
	self.rails_loaded.emit(self.tracks)
	
func spawn_rails():
	for track_obj in GlobalState.tracks:
		spawn_rail_track(track_obj)
	# emit signals
	self.rails_spawned.emit(track_containers)
	SignalBus.rails_spawned.emit()
	
func spawn_rail_track(track_obj: RailTrack):
	var instanciated: OuterRailTrack = track_obj.spawn()
	add_child(instanciated, true)
	track_obj.scene_node = instanciated
	self.track_containers.append(instanciated)
	# add to rails group as well
	add_to_group("Rails")
	# emit
	SignalBus.rail_spawned.emit(instanciated)
		
func align_tracks():
	for track: RailTrack in GlobalState.tracks:
		var path_3d: Path3D = track.node.get_child(1)
		for index in path_3d.curve.point_count:
			var vec_pos: Vector3 = path_3d.curve.get_point_position(index)
			var terr_height: float = terrain_container.get_height_at(vec_pos)
			var target: Vector3 = Vector3(vec_pos.x, terr_height, vec_pos.z)
			path_3d.curve.set_point_position(index, target)
	
func _ready() -> void:
	load_rail_tracks()
	spawn_rails()
	Loggie.info("rails precreated")

func _on_scene_ready() -> void:
	pass
