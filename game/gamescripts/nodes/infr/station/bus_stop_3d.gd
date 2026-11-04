@icon("res://assets/icons/nodes_3d/icon_station.svg")
class_name BusStop3D extends InventoryEntity3D

const SIGN_SCENE_PATH: String = "res://scenes/subscenes/infr/station/sign/station_sign_3d.tscn"

signal station_assigned(station_obj: RoadStationData)
signal station_placed(world_position: Vector3)

var _road_heading: Vector3 = Vector3.FORWARD
var _roadside_offset: float = 0.0
var _has_road_layout: bool = false
var _sign: StationSign3D

## The Resource owns station identity and position, as with rail stations.
@export var station: RoadStationData:
	get(): return self.entity as RoadStationData
	set(value):
		if self.station == value:
			return
		self._disconnect_station()
		self.entity = value
		self._connect_station()
		self._apply_station()
		self.station_assigned.emit(value)

func _enter_tree() -> void:
	self._connect_station()
	self._apply_station()

func _ready() -> void:
	super()
	self._sign = load(SIGN_SCENE_PATH).instantiate()
	self._sign.name = "StationSign3D"
	self._sign.position = Vector3(0, 15, 0)
	self.add_child(self._sign)
	self._sign.bind_station(self.station, self.get_inventory())

func _connect_station() -> void:
	if self.station != null and not self.station.positioned.is_connected(self._on_station_positioned):
		self.station.positioned.connect(self._on_station_positioned)

func _disconnect_station() -> void:
	if self.station != null and self.station.positioned.is_connected(self._on_station_positioned):
		self.station.positioned.disconnect(self._on_station_positioned)

func _apply_station() -> void:
	if self.station != null:
		self._on_station_positioned(self.station.position)
	var model := self.get_node_or_null("Model") as Node3D
	if model != null:
		model.visible = self.station == null or not self.station.hide_building
	if is_instance_valid(self._sign):
		self._sign.bind_station(self.station, self.get_inventory())

func _on_station_positioned(world_position: Vector3) -> void:
	if self.is_inside_tree():
		self.global_position = world_position
	else:
		# Reapplied on tree entry, once the parent's world transform is available.
		self.position = world_position
	self.station_placed.emit(world_position)
	if self._has_road_layout and self.is_inside_tree():
		self._layout_shelters()

func configure_road_layout(heading: Vector3, offset_metres: float) -> void:
	self._road_heading = heading.normalized()
	self._roadside_offset = offset_metres
	self._has_road_layout = true
	self._layout_shelters()

func _layout_shelters() -> void:
	if self.station == null:
		return
	var shelter := self.get_node("Model/Shelter") as Node3D
	var opposite := self.get_node_or_null("Model/OppositeShelter") as Node3D
	# BOTH is one logical stop/inventory with two visual shelters, not two
	# different IDs or duplicated passenger queues.
	if self.station.road_side == Enums.RoadSide.BOTH and opposite == null:
		opposite = shelter.duplicate() as Node3D
		opposite.name = "OppositeShelter"
		self.get_node("Model").add_child(opposite)
	elif self.station.road_side != Enums.RoadSide.BOTH and opposite != null:
		opposite.free()
		opposite = null
	var sign: float = -1.0 if self.station.road_side == Enums.RoadSide.LEFT else 1.0
	self._place_shelter(shelter, sign)
	if opposite != null:
		self._place_shelter(opposite, -1.0)

## The authored shelter runs along Z and opens toward -X. Align its long edge
## with the road, reversing the opposite side so both entrances face the road.
func _place_shelter(shelter: Node3D, side_sign: float) -> void:
	var right: Vector3 = self._road_heading.cross(Vector3.UP).normalized()
	shelter.global_position = self.station.position + right * self._roadside_offset * side_sign
	if not self._road_heading.is_zero_approx():
		shelter.look_at(shelter.global_position + self._road_heading * side_sign)

func _exit_tree() -> void:
	self._disconnect_station()
	super()
