@icon("res://assets/icons/nodes_3d/icon_station.svg")
class_name NodeStationLink3D extends GameEntity3D

const STATION_SCENE := preload("res://scenes/subscenes/infr/station/rail_node_station_3d.tscn")
const DEFAULT_BUILDING := preload("res://assets/meshes/infr/stops/passenger_platform/passenger_platform.tscn")

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

static func of(link: NodeStationLinkData, building: RailPlatform3D = null) -> NodeStationLink3D:
	var instance := STATION_SCENE.instantiate() as NodeStationLink3D
	instance.node_station = link
	if building == null:
		building = DEFAULT_BUILDING.instantiate() as RailPlatform3D
	building.name = "StationBuilding3D"
	building.node_link_3d = instance
	instance.add_child(building)
	return instance
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
		basis = placement_basis(self.node_station.parent_node.parent_track.curve, station.curve_offset, station.platform_side)
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
	self.rotate_y(GameConstants.NINETY_DEG_IN_RAD)

static func placement_basis(curve: Curve3D, offset: float, side: RailStationData.PlatformSide) -> Basis:
	var heading: Vector3 = curve.sample_baked(minf(curve.get_baked_length(), offset + 0.2)) \
		- curve.sample_baked(maxf(0.0, offset - 0.2))
	heading.y = 0.0
	if heading.is_zero_approx():
		return Basis.IDENTITY
	var rotation: float = GameConstants.NINETY_DEG_IN_RAD
	if side == RailStationData.PlatformSide.LEFT:
		rotation += PI
	return Basis.looking_at(-heading).rotated(Vector3.UP, rotation)

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
