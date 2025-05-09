class_name RailsLoader extends Node3D

const rails_json_path = "res://world/jsondata/tracks.json"

@onready var globals: Globals = %Globals
@onready var rails = %Rails
@onready var terrain: Terrain3D = %WorldTerrain
@export var tracks: Array[RailTrack] = []

signal rails_loaded(_rails: Array[RailTrack])
signal rails_spawned(_rails: Array[RailTrackContainer])

func load_rails() -> void:
	var rails_arr_str: String = FileAccess.get_file_as_string(rails_json_path)
	var rails_json_arr: Array = JSON.parse_string(rails_arr_str)
	for json_track in rails_json_arr:
		var rail_track: RailTrack = RailTrack.from_json(json_track)
		self.tracks.append(rail_track)
	globals.tracks = self.tracks
	self.rails_loaded.emit(self.tracks)
	
func spawn_rails():
	var track_containers: Array[RailTrackContainer] = []
	for track in globals.tracks:
		var instanciated: RailTrackContainer = track.spawn()
		add_child(instanciated)
		track.node = instanciated
		track_containers.append(instanciated)
	self.rails_spawned.emit(track_containers)
	return track_containers
		
func align_tracks():
	for track: RailTrack in globals.tracks:
		var path_3d: Path3D = track.node.get_child(1)
		for index in path_3d.curve.point_count:
			var vec_pos: Vector3 = path_3d.curve.get_point_position(index)
			var terr_height: float = terrain.data.get_height(vec_pos)
			var target: Vector3 = Vector3(vec_pos.x, terr_height, vec_pos.z)
			path_3d.curve.set_point_position(index, target)
func _on_terrain_ready():
	print("terrain ready")
func _ready() -> void:
	load_rails()
	spawn_rails()
	print("rails precreated")

func _on_scene_ready() -> void:
	pass
