@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailsLoader extends AbstractTrackLoader

const MAP_RAILS_FILEPATH_FORMAT := "res://world/%s/jsondata/tracks.json"
const RAILS_INFR_GROUP := "Rails"
const MAX_VISIBLE_DIST := 300
const BUFFER_PATH = "res://assets/meshes/infr/rail/rail_buffer_750mm/rail_buffer_750mm.tscn"

@export var track_storage: RailTrackStore = RailTrackStore.new()
@export var fork_storage: RailJunctionArmStore = RailJunctionArmStore.new()
@export var outer_buffers: Array[RailBuffer3D] = []
## Block signals placed in this session.
@export var signals: RailSignalStore = RailSignalStore.new()

@export var builder: NewRailBuilder:
	get(): return $NewRailBuilder as NewRailBuilder

## Built on first use after any track is added or the network is edited.
var _network_graph: RailNetworkGraph

func _init() -> void:
	network_changed.connect(_invalidate_network_graph)
	track_storage.track_added.connect(_invalidate_network_graph.unbind(1))

func _ready() -> void:
	var tool: Node = load("res://game/gamescripts/nodes/marker/rail_signal_tool.gd").new()
	tool.name = "RailSignalTool"
	tool.rails = self
	add_child(tool)

## Track data links both ways: track ↔ nodes, node ↔ fork leg and station link, leg ↔ junction.
## Reference counting cannot free such cycles, so break them when the loader goes away.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		release_network()

func release_network() -> void:
	for track: RailTrackData in track_storage.get_all():
		for node: RailNodeData in track.nodes:
			if node.fork != null:
				var junction: RailJunctionData = node.fork.junction
				if junction != null:
					junction.release_legs()
				node.fork.junction = null
				node.fork.railNode = null
				node.fork = null
		track.nodes.clear()
		track.forks.clear()

## Directed track graph shared by route finding and, later, signal blocks.
func get_network_graph() -> RailNetworkGraph:
	if _network_graph == null:
		_network_graph = RailNetworkGraph.new()
		_network_graph.build(track_storage.get_all())
	return _network_graph

func _invalidate_network_graph() -> void:
	_network_graph = null

#region Initialization
func load_rail_tracks() -> void:
	Loggie.info("Loading rail track from json..")
	var rail_file_path := MAP_RAILS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var rails_arr_str: String = FileAccess.get_file_as_string(rail_file_path)
	for json_track in JSON.parse_string(rails_arr_str):
		var rail_track: RailTrackData = RailMapper.rail_track_from_dict(json_track)
		# Register fork legs before the track: the fork loader groups them on track_added.
		for node: RailNodeData in rail_track.nodes:
			if node.fork != null:
				self.fork_storage.add(node.fork)
		self.track_storage.add(rail_track)
	# trigger signal
	SignalBus.rails_loaded.emit(self.track_storage.get_all())
#endregion

#region RailTrack Spawning
func spawn_rails():
	for track_obj: RailTrackData in self.track_storage.get_all():
		self.spawn_rail_track(track_obj)
		self.spawn_rail_buffers(track_obj)
	# emit signals
	SignalBus.rails_spawned.emit(self.track_storage.get_containers())

func instanciate_rail_track(rail_track: RailTrackData) -> RailTrack3D:
	var outer_track := RailTrack3D.of(rail_track)
	GlobalState.outer_tracks.append(outer_track)
	return outer_track

func spawn_rail_track(track_obj: RailTrackData) -> RailTrack3D:
	var outer_track := self.instanciate_rail_track(track_obj)
	# save in storage and as child
	self.track_storage.add_container(outer_track)
	add_child(outer_track, true)
	# emit
	SignalBus.rail_spawned.emit(outer_track)
	return outer_track
#endregion

#region Rail Buffers
func spawn_rail_buffers(parent_track: RailTrackData):
	for rail_node: RailNodeData in parent_track.nodes:
		if rail_node.is_end == true:
			self.spawn_buffer(rail_node)

func spawn_buffer(rail_node: RailNodeData) -> RailBuffer3D:
	var outer_buffer: RailBuffer3D = load(BUFFER_PATH).instantiate()
	outer_buffer.parent_node = rail_node
	# add to list & as own child
	self.outer_buffers.append(outer_buffer)
	self.add_child(outer_buffer)
	return outer_buffer
#endregion

#region Event Listeners
func _on_map_spawned(_container: WorldMapScene):
	self.spawn_rails()

func _on_map_selected(_selected_map: MapData):
	self.load_rail_tracks()
#endregion

## Disconnect this fork leg. If fewer than two legs remain, remove the junction.
func erase_fork(track: RailTrackData, index: int) -> Error:
	if not _has_track(track) or not track.has_node_index(index):
		return ERR_INVALID_PARAMETER
	var node: RailNodeData = track.nodes[index]
	if node.fork == null:
		return ERR_DOES_NOT_EXIST
	var group: RailJunctionData = node.fork.junction
	if _track_has_active_train(track) or _fork_has_active_train(group):
		return ERR_BUSY
	var removed: RailJunctionArm = node.fork
	_remove_fork_leg(removed, false)
	_reconcile_fork(group, [removed])
	fork_storage.rebuild_indexes()
	network_changed.emit()
	return OK


#region Split hooks
func _store() -> AbstractTrackStore:
	return track_storage


func _new_track() -> AbstractInfrLine:
	return RailTrackData.new()


func _spawn_view(track: AbstractInfrLine) -> void:
	spawn_rail_track(track)


func _split_blocker(track: AbstractInfrLine) -> Error:
	var rail := track as RailTrackData
	if _track_has_dependencies(rail):
		return ERR_BUSY
	for group: RailJunctionData in _junctions_of(rail.nodes):
		if _fork_has_active_train(group):
			return ERR_BUSY
	return OK


func _copy_track_fields(fragment: AbstractInfrLine, source: AbstractInfrLine) -> void:
	super(fragment, source)
	(fragment as RailTrackData).hideFill = (source as RailTrackData).hideFill


## A cut end without a fork leg becomes a buffer stop.
func _init_fragment(fragment: AbstractInfrLine, cut_start: bool, cut_end: bool) -> void:
	var rail := fragment as RailTrackData
	if cut_start:
		rail.start_tangent = Vector3.ZERO
	rail.forks.clear()
	for node: RailNodeData in rail.nodes:
		if node.fork != null:
			rail.forks.append(node.fork)
	if cut_start and rail.nodes.front().fork == null:
		rail.nodes.front().is_end = true
	if cut_end and rail.nodes.back().fork == null:
		rail.nodes.back().is_end = true


func _relink(split: AbstractTrackLoader.Split) -> void:
	# Collect before the erased legs forget their junction.
	var junctions: Array[RailJunctionData] = _junctions_of(split.old_nodes)
	var removed_legs: Array[RailJunctionArm] = []
	for node: RailNodeData in split.removed_nodes():
		_remove_buffer(node)
		if node.fork != null:
			removed_legs.append(node.fork)
			_remove_fork_leg(node.fork, true)
	for junction: RailJunctionData in junctions:
		_reconcile_fork(junction, removed_legs)
	fork_storage.rebuild_indexes()


func _on_fragment_shown(fragment: AbstractInfrLine, has_view: bool) -> void:
	if has_view:
		var rail := fragment as RailTrackData
		for endpoint: RailNodeData in [rail.nodes.front(), rail.nodes.back()]:
			_ensure_buffer(endpoint)
#endregion


func _junctions_of(nodes: Array) -> Array[RailJunctionData]:
	var junctions: Array[RailJunctionData] = []
	for node: RailNodeData in nodes:
		if node.fork != null and node.fork.junction != null and node.fork.junction not in junctions:
			junctions.append(node.fork.junction)
	return junctions


func _fork_loader() -> RailJunctionLoader:
	var loader: RailJunctionLoader = get_node_or_null("RailJunctionLoader")
	if loader == null and Managers.rails == self:
		loader = Managers.forks
	return loader


func _remove_fork_leg(leg: RailJunctionArm, removing_node: bool) -> void:
	var node: RailNodeData = leg.railNode
	var track := node.parent_track as RailTrackData
	track.forks.erase(leg)
	fork_storage.remove(leg)
	node.fork = null
	leg.connective_tracks.clear()
	leg.junction = null
	leg.container = null
	if not removing_node and (node.is_first() or node.is_last()):
		node.is_end = true
		if track_storage.find_container(track.num) != null:
			_ensure_buffer(node)


func _reconcile_fork(group: RailJunctionData, removed: Array[RailJunctionArm]) -> void:
	if group == null:
		return
	var root: RailJunctionArm
	var connected: RailJunctionArm
	if group.setting.current != null:
		root = _find_fork_leg(group, group.setting.current.root)
		connected = _find_fork_leg(group, group.setting.current.connected)
	for leg: RailJunctionArm in removed:
		group.node_forks.erase(leg)
	group.connected_tracks.clear()
	group.static_tracks.clear()
	group.setting.settable_tracks.clear()
	group.setting.current = null
	if group.node_forks.size() < 2:
		for orphan: RailJunctionArm in group.node_forks:
			_remove_fork_leg(orphan, false)
		group.node_forks.clear()
		var loader: RailJunctionLoader = _fork_loader()
		loader.forks_by_pos.erase(group.pos)
		if loader.forks_spawned.is_connected(group.refresh_setting):
			loader.forks_spawned.disconnect(group.refresh_setting)
		if is_instance_valid(group.fork3d):
			if group.fork3d.get_parent() != null:
				group.fork3d.get_parent().remove_child(group.fork3d)
			group.fork3d.queue_free()
			group.fork3d = null
		group.setting.parent = null
		return
	for leg: RailJunctionArm in group.node_forks:
		group.connected_tracks.append(leg.track.num)
		if leg.static_track:
			group.static_tracks.append(leg.track.num)
	if root in group.node_forks and connected in group.node_forks:
		group.setting.current = CurrentJunctionSetting.new(root.track.num, connected.track.num)
	group.refresh_setting()
	for leg: RailJunctionArm in group.node_forks:
		leg.connective_tracks.assign(group.connected_tracks)
		leg.connective_tracks.erase(leg.track.num)
	if is_instance_valid(group.fork3d):
		group.fork3d.adjust_rotation.call_deferred()


func _find_fork_leg(group: RailJunctionData, track_num: int) -> RailJunctionArm:
	var index: int = group.connected_tracks.find(track_num)
	return group.node_forks[index] if index >= 0 else null


func _ensure_buffer(node: RailNodeData) -> void:
	if not node.is_end:
		return
	for buffer: RailBuffer3D in outer_buffers:
		if buffer.parent_node == node:
			buffer.adjust_rotation()
			return
	spawn_buffer(node)


func _remove_buffer(node: RailNodeData) -> void:
	for buffer: RailBuffer3D in outer_buffers:
		if buffer.parent_node == node:
			outer_buffers.erase(buffer)
			remove_child(buffer)
			buffer.queue_free()
			return


func _track_has_dependencies(track: RailTrackData) -> bool:
	## Signal positions are track offsets that an edit cannot rebase safely.
	if not signals.get_on_track(track.num).is_empty():
		return true
	## Stops are placed by node + offset on the track; an edit would move or orphan them.
	if Managers.rails == self and is_instance_valid(Managers.stations) \
			and not Managers.stations.stops_on_track(track.num).is_empty():
		return true
	if Managers.rails == self and is_instance_valid(Managers.depots):
		for depot: RailDepotData in Managers.depots.rail_depots:
			if depot.track_num == track.num:
				return true
	return _track_has_active_train(track)


func _track_has_active_train(track: RailTrackData) -> bool:
	if Managers.rails != self or not is_instance_valid(Managers.vehicles):
		return false
	for train: Train3D in Managers.vehicles.trains:
		if not is_instance_valid(train) or train.movement == null or not is_instance_valid(train.movement.active_path):
			continue
		for segment: VehiclePathSegment in train.movement.active_path.segments:
			if segment.track_num == track.num:
				return true
	return false


func _fork_has_active_train(group: RailJunctionData) -> bool:
	if group != null:
		for leg: RailJunctionArm in group.node_forks:
			if _track_has_active_train(leg.track):
				return true
	return false
