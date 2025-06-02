@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailsLoader extends Node

const rails_json_path := "res://world/jsondata/tracks.json"
const rails_group := "Rails"
const MAX_VISIBLE_DIST := 500

@export var tracks: Array[RailTrack] = []
@export var track_containers: Array[OuterRailTrack] = []

signal rails_loaded(_rails: Array[RailTrack])
signal rails_spawned(_rails: Array[OuterRailTrack])

func _enter_tree() -> void:
	SignalBus.scene_root_ready.connect(Callable(self, "_on_scene_ready"))
	SignalBus.world_update.connect(Callable(self, "_on_world_update"))

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
	SignalBus.rails_spawned.emit(track_containers)
	
func spawn_rail_track(track_obj: RailTrack):
	var instanciated: OuterRailTrack = track_obj.spawn()
	add_child(instanciated, true)
	self.track_containers.append(instanciated)
	# add to rails group as well
	add_to_group("Rails")
	# emit
	SignalBus.rail_spawned.emit(instanciated)
		
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
