@icon("res://assets/icons/nodes_3d/icon_station.svg")
class_name NodeStationLink3D extends GameEntity3D

const STATION_SCENE_PATH = "uid://bfibk5fcr42yy"

signal node_station_changed(node_station: NodeStationLinkData)

@export var node_station: NodeStationLinkData:
	get(): return self.entity as NodeStationLinkData
	set(value): 
		self.entity = value
		self.position = value.position
		self.node_station_changed.emit(value)

#region Initialization
func _enter_tree() -> void:
	# hide building on flag == true
	if self.node_station.hide_building == true:
		$StationBuilding3D.hide_building()
	# connect to signals
	self.node_station_changed.connect(Callable(self, "_on_node_station_changed"))

func _ready() -> void:
	self._on_node_station_changed(self.node_station)

static func of(_node_station: NodeStationLinkData) -> NodeStationLink3D:
	var prefab: PackedScene = preload(STATION_SCENE_PATH)
	var instanciated_container: NodeStationLink3D = prefab.instantiate()
	instanciated_container.node_station = _node_station
	return instanciated_container
#endregion

#region Getters
func get_parent_station_3d() -> RailStation3D:
	var parent_station_num = self.node_station.parent_station_num
	return Managers.stations.get_station_3d_with_num(parent_station_num)
#endregion

#region Helper-Methods
func adjust_rotation_from_track():
	var station: RailStationData = self.node_station.parent_station
	if station.curve_offset >= 0.0:
		var curve: Curve3D = self.node_station.parent_node.parent_track.curve
		var offset: float = station.curve_offset
		var heading: Vector3 = curve.sample_baked(minf(curve.get_baked_length(), offset + 0.2)) - curve.sample_baked(maxf(0.0, offset - 0.2))
		heading.y = 0.0
		if not heading.is_zero_approx():
			self.look_at(self.global_position - heading)
			self.rotate_y(WorldUtils.NINETY_DEG_IN_RAD)
		return
	var track_node: RailNodeData = self.node_station.parent_node
	var prev_node: RailNodeData = self.get_parent_track_node_by_index(track_node.index -1)
	var next_node: RailNodeData = self.get_parent_track_node_by_index(track_node.index +1)
	# Node zero has no previous node. Extrapolate the approach from its next
	# neighbour instead of dereferencing null when a JSON stop starts a track.
	var approach: Vector3 = Vector3.ZERO
	if prev_node != null:
		approach = prev_node.position - track_node.position
	elif next_node != null:
		approach = track_node.position - next_node.position
	approach.y = 0.0
	if approach.is_zero_approx():
		return
	self.look_at(self.global_position + approach)
	self.rotate_y(WorldUtils.NINETY_DEG_IN_RAD)

func get_parent_track_node_by_index(_i: int) -> RailNodeData:
	var track: RailTrackData = self.node_station.parent_node.parent_track
	return track.get_rail_node(_i)

func _to_string() -> String:
	return "OuterStation-%s@%s" % [self.station_name, self.town_name]
#endregion

#region Callbacks & Triggers
func _on_node_station_changed(_node_station: NodeStationLinkData):
	if !_node_station.parent_station:
		Loggie.error("Cannot find parent station of NodeStation in %s" % _node_station.town_name)
		return
	# find parent Station3D
	var parent_station_3d: RailStation3D = self.get_parent_station_3d()
	# connect parent station to trains entering or exiting
	$Area3D.parent_station_3d = parent_station_3d
#endregion
