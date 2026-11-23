## The platform of one rail stop: building, sign and the catchment area trains and the player enter.
## Its entity is the RailStationData itself. (The name is historical: it used to show a NodeStationLinkData,
## a link object between rail node and stop that was removed on 2026-11-23.)
@icon("res://assets/icons/nodes_3d/icon_station.svg")
class_name NodeStationLink3D extends GameEntity3D

const STATION_SCENE := preload("res://scenes/subscenes/infr/station/rail_node_station_3d.tscn")
const DEFAULT_BUILDING := preload("res://assets/meshes/infr/stops/passenger_platform/passenger_platform.tscn")

signal stop_changed(stop: RailStationData)

@export var stop: RailStationData:
	get(): return self.entity as RailStationData
	set(value):
		self.entity = value
		self.position = value.position
		self.stop_changed.emit(value)

#region Initialization
func _enter_tree() -> void:
	# hide building on flag == true
	if self.stop.hide_building == true:
		$StationBuilding3D.hide_building()
	# connect to signals
	self.stop_changed.connect(self._on_stop_changed)

func _ready() -> void:
	self._on_stop_changed(self.stop)

static func of(rail_stop: RailStationData, building: RailPlatform3D = null) -> NodeStationLink3D:
	var instance := STATION_SCENE.instantiate() as NodeStationLink3D
	instance.stop = rail_stop
	if building == null:
		building = DEFAULT_BUILDING.instantiate() as RailPlatform3D
	building.name = "StationBuilding3D"
	building.node_link_3d = instance
	instance.add_child(building)
	return instance
#endregion

#region Getters
func get_parent_station_3d() -> RailStation3D:
	return Managers.stations.get_station_3d_with_num(self.stop.num)
#endregion

#region Helper-Methods
## Turn the platform along the track at its anchor, on the stop's platform side.
## Until 2026-11-23, stops placed on a node were turned toward the previous node instead (and ignored
## the platform side). Both give the same direction on straight track; on a curve, the tangent used now
## follows the track at the platform rather than the chord to the previous node.
func adjust_rotation_from_track():
	var track: RailTrackData = Managers.rails.track_storage._by_id.get(self.stop.track_num)
	if track == null or not self.stop.anchor.is_valid_on(track):
		return
	basis = placement_basis(track.ensure_curve(), self.stop.anchor.curve_offset(track), self.stop.platform_side)

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

func _to_string() -> String:
	return "OuterStation-%s@%s" % [self.stop.station_name, self.stop.town_name] if self.stop != null else "OuterStation"
#endregion

#region Callbacks & Triggers
func _on_stop_changed(_stop: RailStationData):
	if _stop == null:
		Loggie.error("Rail platform %s has no stop" % self.name)
		return
	# connect parent station to trains entering or exiting
	$Area3D.parent_station_3d = self.get_parent_station_3d()
#endregion
