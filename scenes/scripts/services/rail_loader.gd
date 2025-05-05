@tool
extends Node3D

const rails_json_path = "res://world/jsondata/tracks.json"

@onready var terrain: Terrain3D = %WorldTerrain

func load_rails() -> void:
	var tracks: Array[RailTrack] = []
	var rails_arr_str: String = FileAccess.get_file_as_string(rails_json_path)
	print(rails_arr_str)
	var rails_json_arr: Array = JSON.parse_string(rails_arr_str)
	for json_track in rails_json_arr:
		var rail_track: RailTrack = RailTrack.from_json(json_track)
		tracks.append(rail_track)
	GlobalStore.tracks = tracks
	
func spawn_rails():
	for track in GlobalStore.tracks:
		var instanciated = track.spawn()
		add_child(instanciated)
		track.node = instanciated
		
func align_tracks():
	for track: Node3D in GlobalStore.tracks:
		var path_3d: Path3D = track.node.get_child(1)
		for index in path_3d.curve.point_count:
			var vec_pos: Vector3 = path_3d.curve.get_point_position(index)
			var terr_height: float = terrain.data.get_height(vec_pos)
			var target: Vector3 = Vector3(vec_pos.x, terr_height, vec_pos.z)
			path_3d.curve.set_point_position(index, target)

func _ready() -> void:
	load_rails()
	spawn_rails()
	print("rails precreated")

func _on_terrain_ready():
	print("terrain ready")

func _on_scene_ready() -> void:
	pass
