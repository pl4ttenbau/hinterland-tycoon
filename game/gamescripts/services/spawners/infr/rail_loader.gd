@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailsLoader extends Node

const MAP_RAILS_FILEPATH_FORMAT := "res://world/%s/jsondata/tracks.json"
const RAILS_INFR_GROUP := "Rails"
const MAX_VISIBLE_DIST := 300
const BUFFER_PATH = "res://assets/meshes/infr/rail/rail_buffer_750mm/rail_buffer_750mm.tscn"

@export var track_storage: RailTrackStore = RailTrackStore.new()
@export var fork_storage: RailForkStore = RailForkStore.new()

## here we only store visible forks
@export var visible_forks: Array[RailNodeForkData] = []
@export var visible_forks_by_pos: Dictionary = {}

@export var outer_buffers: Array[OuterRailBuffer] = []

func _enter_tree() -> void:
	Managers.rails = self
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))
	SignalBus.map_selected.connect(Callable(self, "_on_map_selected"))

	
func _ready() -> void:
	# self.load_rail_tracks()
	# Loggie.info("rails precreated")
	pass

func load_rail_tracks() -> void:
	var rail_file_path := MAP_RAILS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var rails_arr_str: String = FileAccess.get_file_as_string(rail_file_path)
	for json_track in JSON.parse_string(rails_arr_str):
		var rail_track: RailTrackData = RailMapper.rail_track_from_dict(json_track)
		self.track_storage.add(rail_track)
	# trigger signal
	SignalBus.rails_loaded.emit(self.track_storage.get_all())

#region RailTrack Spawning
func spawn_rails():
	for track_obj: RailTrackData in self.track_storage.get_all():
		self.spawn_rail_track(track_obj)
		self.spawn_rail_buffers(track_obj)
	# emit signals
	SignalBus.rails_spawned.emit(self.track_storage._containers)
	
func instanciate_rail_track(rail_track: RailTrackData) -> OuterRailTrack:
	if ! rail_track.curve: rail_track.build_path()
	# instanciate Container from PackedScene
	var outer_track: OuterRailTrack = load(OuterRailTrack.get_scene_path(rail_track)).instantiate()
	outer_track.track = rail_track
	GlobalState.outer_tracks.append(outer_track)
	return outer_track
	
func spawn_rail_track(track_obj: RailTrackData):
	var outer_track := self.instanciate_rail_track(track_obj)
	# save in storage and as child
	self.track_storage.add_container(outer_track)
	add_child(outer_track, true)
	# emit
	SignalBus.rail_spawned.emit(outer_track)
#endregion

#region Rail Buffers
func spawn_rail_buffers(parent_track: RailTrackData):
	for rail_node: RailNodeData in parent_track.nodes:
		if rail_node.is_end == true:
			self.spawn_buffer(rail_node)
			
func spawn_buffer(rail_node: RailNodeData) -> OuterRailBuffer:
	var outer_buffer: OuterRailBuffer = load(BUFFER_PATH).instantiate()
	outer_buffer.parent_node = rail_node
	# add to list & as own child
	self.outer_buffers.append(outer_buffer)
	self.add_child(outer_buffer)
	return outer_buffer
#endregion

#region Event Listeners
func _on_map_spawned(_container: TerrainContainer):
	self.spawn_rails()
	
func _on_map_selected(selected_map: MapData):
	self.load_rail_tracks()
#endregion
