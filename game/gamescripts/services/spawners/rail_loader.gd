@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailsLoader extends Node

const MAP_RAILS_FILEPATH_FORMAT := "res://world/%s/jsondata/tracks.json"
const RAILS_INFR_GROUP := "Rails"
const MAX_VISIBLE_DIST := 300
const BUFFER_PATH = "res://assets/meshes/infr/rail/rail_buffer_750mm/rail_buffer_750mm.tscn"

@export var tracks: Array[RailTrackData] = []
@export var track_containers: Array[OuterRailTrack] = []
@export var tracks_by_num: Dictionary = {}

@export var forks: Array[RailForkData] = []
@export var outer_forks: Array[OuterRailFork] = []
@export var forks_by_pos: Dictionary = {}

@export var outer_buffers: Array[OuterRailBuffer] = []

func _enter_tree() -> void:
	Managers.rails = self
	SignalBus.world_update.connect(Callable(self, "_on_world_update"))
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))
	
func _ready() -> void:
	self.load_rail_tracks()
	self.sort_rail_forks()
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
		self.spawn_rail_buffers(track_obj)
	self.spawn_rail_forks()
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
#endregion

#region Rail Children Spawning
func sort_rail_forks():
	for rail_track in self.tracks:
		for track_node in rail_track.nodes:
			if track_node.fork:
				if ! self.forks_by_pos.has(track_node.position):
					self.forks_by_pos.set(track_node.position, track_node.fork)
					self.forks.append(track_node.fork)
					GlobalState.forks.append(track_node.fork)

func spawn_rail_forks():
	for fork: RailForkData in self.forks:
		fork.spawn()
		fork.container.adjust_rotation()
		
func spawn_rail_buffers(parent_track: RailTrackData):
	for rail_node: RailNodeData in parent_track.nodes:
		if rail_node.is_end == true:
			self.spawn_buffer(rail_node)
			
func spawn_buffer(rail_node: RailNodeData) -> OuterRailBuffer:
	var outer_buffer: OuterRailBuffer = load(BUFFER_PATH).instantiate()
	outer_buffer.parent_node = rail_node
	outer_buffer.adjust_rotation()
	# add to list
	self.outer_buffers.append(outer_buffer)
	# and as track child
	self.add_child(outer_buffer)
	return outer_buffer
#endregion

func hide_far_rails():
	for container: OuterRailTrack in self.track_containers:
		var player: Node3D = %Player
		if player:
			var middle_pos: Vector3 = container.get_middle_pos()
			var dist = self._get_cam_pos().distance_to(middle_pos)
			if dist > MAX_VISIBLE_DIST: container.visible = false
			else: container.visible = true

#region Event Listeners
func _on_map_spawned(_container: TerrainContainer):
	self.spawn_rails()
	
func _on_world_update() -> void:
	# self.hide_far_rails()
	pass
	
#endregion

#region Helper-Methods
func _get_cam_pos() -> Vector3:
	if GlobalState.active_cam != null:
		return GlobalState.active_cam.global_position
	return GlobalState.player.global_position
#endregion
