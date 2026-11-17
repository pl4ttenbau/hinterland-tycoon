@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailsLoader extends Node

const MAP_RAILS_FILEPATH_FORMAT := "res://world/%s/jsondata/tracks.json"
const RAILS_INFR_GROUP := "Rails"
const MAX_VISIBLE_DIST := 300
const BUFFER_PATH = "res://assets/meshes/infr/rail/rail_buffer_750mm/rail_buffer_750mm.tscn"

signal network_changed()

@export var track_storage: RailTrackStore = RailTrackStore.new()
@export var fork_storage: RailNodeForkStore = RailNodeForkStore.new()
@export var outer_buffers: Array[RailBuffer3D] = []

@export var builder: NewRailBuilder:
	get(): return $NewRailBuilder as NewRailBuilder

#region Initialization
func load_rail_tracks() -> void:
	Loggie.info("Loading rail track from json..")
	var rail_file_path := MAP_RAILS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var rails_arr_str: String = FileAccess.get_file_as_string(rail_file_path)
	for json_track in JSON.parse_string(rails_arr_str):
		var rail_track: RailTrackData = RailMapper.rail_track_from_dict(json_track)
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
	SignalBus.rails_spawned.emit(self.track_storage._containers)

func instanciate_rail_track(rail_track: RailTrackData) -> RailTrack3D:
	if ! rail_track.curve: rail_track.build_curve()
	# instanciate Container from PackedScene
	var outer_track: RailTrack3D = load(RailTrack3D.get_scene_path(rail_track)).instantiate()
	outer_track.track = rail_track
	GlobalState.outer_tracks.append(outer_track)
	return outer_track

func spawn_rail_track(track_obj: RailTrackData) -> RailTrack3D:
	var outer_track := self.instanciate_rail_track(track_obj)
	_fit_path_meshes(outer_track, track_obj.curve)
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


## A segment is the span between adjacent authored nodes.
func erase_segment(track: RailTrackData, segment_index: int) -> Error:
	return erase_span(track, segment_index, segment_index + 1)


## The selected endpoints survive if they still have a span on their outside.
func erase_span(track: RailTrackData, from_index: int, to_index: int) -> Error:
	var first: int = mini(from_index, to_index)
	var last: int = maxi(from_index, to_index)
	if not _has_track(track) or first < 0 or last >= track.nodes.size() or first == last:
		return ERR_INVALID_PARAMETER
	return _erase_gap(track, first, last)


## Erase the node and both incident spans, leaving a gap.
func erase_node(track: RailTrackData, index: int) -> Error:
	if not _has_track(track) or index < 0 or index >= track.nodes.size():
		return ERR_INVALID_PARAMETER
	return _erase_gap(track, index - 1, index + 1)


## Disconnect this fork leg. If fewer than two legs remain, remove the junction.
func erase_fork(track: RailTrackData, index: int) -> Error:
	if not _has_track(track) or index < 0 or index >= track.nodes.size():
		return ERR_INVALID_PARAMETER
	var node: RailNodeData = track.nodes[index]
	if node.fork == null:
		return ERR_DOES_NOT_EXIST
	var group: NewRailForkData = _fork_at(node.position)
	if _track_has_active_train(track) or _fork_has_active_train(group):
		return ERR_BUSY
	var removed: RailNodeForkData = node.fork
	_remove_fork_leg(removed, false)
	_reconcile_fork(group, [removed])
	fork_storage.rebuild_indexes()
	network_changed.emit()
	return OK


func _has_track(track: RailTrackData) -> bool:
	return track != null and track_storage._by_id.get(track.num) == track


func _erase_gap(track: RailTrackData, left_end: int, right_start: int) -> Error:
	if _track_has_dependencies(track):
		return ERR_BUSY
	var junctions: Array[NewRailForkData] = []
	for node: RailNodeData in track.nodes:
		if node.fork == null:
			continue
		var group: NewRailForkData = _fork_at(node.position)
		if group != null and group not in junctions:
			if _fork_has_active_train(group):
				return ERR_BUSY
			junctions.append(group)
	if track.curve == null:
		track.build_curve()
	var source: Curve3D = track.curve
	if source.point_count != track.nodes.size():
		return ERR_INVALID_DATA
	var old_nodes: Array[RailNodeData] = track.nodes
	var fragments: Array[RailTrackData] = []
	var surviving: Dictionary = {}
	var view: RailTrack3D = track_storage._containers_by_id.get(track.num)
	for points: Vector2i in PathCurveUtils.ranges_after_erase(old_nodes.size(), left_end, right_start):
		var section: Curve3D = PathCurveUtils.copy_point_range(source, points, Vector3.ZERO)
		if section.get_baked_length() <= 0.0:
			continue
		var fragment: RailTrackData = track if fragments.is_empty() else RailTrackData.new()
		if fragment != track:
			fragment.num = track_storage._max_num + 1
			fragment.track_name = track.track_name
			fragment.tag = track.tag
			fragment.infr_type_key = track.infr_type_key
			fragment.hideFill = track.hideFill
		if points.x > 0:
			fragment.start_tangent = Vector3.ZERO
		fragment.nodes = old_nodes.slice(points.x, points.y + 1)
		fragment.start_pos = fragment.nodes[0].position
		fragment.vertices = []
		fragment.forks = []
		for node: RailNodeData in fragment.nodes:
			node.parent_track = fragment
			node.index = fragment.vertices.size()
			node.rel_position = node.position - fragment.start_pos
			fragment.vertices.append(node.position)
			surviving[node] = true
			if node.fork != null:
				fragment.forks.append(node.fork)
		if points.x > 0 and fragment.nodes.front().fork == null:
			fragment.nodes.front().is_end = true
		if points.y < old_nodes.size() - 1 and fragment.nodes.back().fork == null:
			fragment.nodes.back().is_end = true
		fragment.abs_aabb = InfrUtils.get_aabb(fragment.vertices)
		fragment.curve = section
		fragments.append(fragment)
	var removed_legs: Array[RailNodeForkData] = []
	for node: RailNodeData in old_nodes:
		if surviving.has(node):
			continue
		_remove_buffer(node)
		if node.fork != null:
			removed_legs.append(node.fork)
			_remove_fork_leg(node.fork, true)
		node.index = -1
		node.parent_track = null
	if fragments.is_empty():
		track_storage.remove(track)
		track.nodes = []
		track.vertices = []
		track.curve = null
	# Publish the fragment ID before any fork view accesses it.
	if fragments.size() == 2:
		track_storage.add(fragments[1])
	for junction: NewRailForkData in junctions:
		_reconcile_fork(junction, removed_legs)
	fork_storage.rebuild_indexes()
	if is_instance_valid(view) and not fragments.is_empty():
		_fit_path_meshes(view, track.curve)
		if fragments.size() == 2:
			spawn_rail_track(fragments[1])
	for fragment: RailTrackData in fragments:
		fragment.curve_built.emit(fragment.curve)
		fragment.track_changed.emit()
		if is_instance_valid(view):
			for endpoint: RailNodeData in [fragment.nodes.front(), fragment.nodes.back()]:
				_ensure_buffer(endpoint)
	network_changed.emit()
	return OK


func _fork_at(position: Vector3) -> NewRailForkData:
	var forks: RailForkLoader = _fork_loader()
	return forks.get_fork_at_pos(position) if forks != null else null


func _fork_loader() -> RailForkLoader:
	var loader: RailForkLoader = get_node_or_null("RailForkLoader")
	if loader == null and Managers.rails == self:
		loader = Managers.forks
	return loader


func _remove_fork_leg(leg: RailNodeForkData, removing_node: bool) -> void:
	var node: RailNodeData = leg.railNode
	var track := node.parent_track as RailTrackData
	track.forks.erase(leg)
	fork_storage.remove(leg)
	node.fork = null
	leg.connective_tracks.clear()
	leg.all_connective_tracks.clear()
	leg.container = null
	if not removing_node and (node.is_first() or node.is_last()):
		node.is_end = true
		if is_instance_valid(track_storage._containers_by_id.get(track.num)):
			_ensure_buffer(node)


func _reconcile_fork(group: NewRailForkData, removed: Array[RailNodeForkData]) -> void:
	if group == null:
		return
	var root: RailNodeForkData
	var connected: RailNodeForkData
	if group.setting.current != null:
		root = _find_fork_leg(group, group.setting.current.root)
		connected = _find_fork_leg(group, group.setting.current.connected)
	for leg: RailNodeForkData in removed:
		group.node_forks.erase(leg)
	group.connected_tracks.clear()
	group.static_tracks.clear()
	group.setting.all_set_to.clear()
	group.setting.settable_tracks.clear()
	group.setting.current = null
	if group.node_forks.size() < 2:
		for orphan: RailNodeForkData in group.node_forks:
			_remove_fork_leg(orphan, false)
		group.node_forks.clear()
		var loader: RailForkLoader = _fork_loader()
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
	for leg: RailNodeForkData in group.node_forks:
		group.connected_tracks.append(leg.track.num)
		if leg.static_track:
			group.static_tracks.append(leg.track.num)
	if root in group.node_forks and connected in group.node_forks:
		group.setting.current = CurrentForkSetting.new(root.track.num, connected.track.num)
	group.refresh_setting()
	for leg: RailNodeForkData in group.node_forks:
		leg.all_connective_tracks.assign(group.connected_tracks)
		leg.connective_tracks.assign(group.connected_tracks)
		leg.connective_tracks.erase(leg.track.num)
		if group.setting.current != null:
			group.setting.all_set_to.append(group.setting.get_next_track_from_track(leg.track.num))
	if is_instance_valid(group.fork3d):
		group.fork3d.adjust_rotation.call_deferred()


func _find_fork_leg(group: NewRailForkData, track_num: int) -> RailNodeForkData:
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
	if not track.node_stations.is_empty():
		return true
	for node: RailNodeData in track.nodes:
		if node.station != null:
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


func _fork_has_active_train(group: NewRailForkData) -> bool:
	if group != null:
		for leg: RailNodeForkData in group.node_forks:
			if _track_has_active_train(leg.track):
				return true
	return false


func _fit_path_meshes(view: RailTrack3D, curve: Curve3D) -> void:
	for child: Node in view.get_children():
		if child is PathMesh3D:
			InfrUtils.fit_short_path_mesh(child, curve)
