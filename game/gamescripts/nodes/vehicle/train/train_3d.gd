@icon("res://assets/icons/nodes_3d/icon_locomotive.svg")
class_name Train3D extends InventoryEntity3D

const EMPTY_SCENE_PATH = "res://scenes/subscenes/vehicle/train_3d.tscn"

signal on_vehicle_added(veh3d: Vehicle3D)

static var _last_train_num: int = 0

@export var num: int

@export var train_obj: TrainData:
	get(): return self.entity as TrainData
	set(value):
		self.entity = value

@export var vehicles: Array[Vehicle3D] = []
@export var locomotive: Vehicle3D

## The train scene wires its movement controller before factory setup or scene insertion.
@export var movement: TrainMovement

@export var current_station = NodeStationLink3D

static func _next_train_num() -> int:
	Train3D._last_train_num += 1
	return Train3D._last_train_num

#region Initialization
## Scene instantiation has created the children, but no runtime dependency is used yet.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		self.movement = self.get_node("TrainMovement")
		self.movement.configure(self)

static func of(_veh_type_key: String, _start_pos: VehicleStartPos) -> Train3D:
	var inst: Train3D = load(EMPTY_SCENE_PATH).instantiate()
	inst.spawn_locomotive(VehicleData.of(_veh_type_key), _start_pos)
	inst.movement.init_segment_path()
	return inst

#endregion

#region Vehicle Spawning
func spawn_locomotive(veh_data: VehicleData, start_pos: VehicleStartPos):
	self.train_obj = TrainData.of(veh_data)
	self.movement.direction = start_pos.dir
	# load vehicle 
	self.add_vehicle(Vehicle3D.of_vehicle_obj(veh_data, self), true)
	# set starting node
	self.movement.last_node = start_pos.track_obj.get_rail_node(start_pos.node_index)

func spawn_wagon(veh_data: VehicleData):
	self.train_obj.append_vehicle(veh_data)
	self.add_vehicle(Vehicle3D.of_vehicle_obj(veh_data, self), false)

func add_vehicle(veh3d: Vehicle3D, is_locomotive: bool = false):
	var num_in_train: int = self.vehicles.size()
	veh3d.num_in_train = num_in_train
	self.vehicles.append(veh3d)
	if is_locomotive: 
		self.locomotive = veh3d
	$TrainVehicles.add_child(veh3d)
	## Vehicles added before entering the scene tree still need their carriage spacing.
	for attached_vehicle: Vehicle3D in self.vehicles:
		attached_vehicle.offset_to_first = attached_vehicle.calc_offset_to_first()
	self.on_vehicle_added.emit(veh3d)
#endregion

#region Size Getters
func count() -> int:
	return self.vehicles.size()

func length_in_m() -> float:
	var total_length: float = 0.0
	for attached_veh: Vehicle3D in self.vehicles:
		if attached_veh.vehicle_obj && attached_veh.vehicle_obj.veh_type:
			total_length += attached_veh.vehicle_obj.veh_type.length_metres
	return total_length
#endregion

#region Node Children Getters
func get_static_body() -> StaticBody3D: return self.get_child(0)

func get_next_node_index() -> int: return self.wheels.target.index

func get_cam() -> Camera3D:
	var model_cam: Camera3D = self.locomotive.find_child("Camera3D", true)
	if !model_cam: Loggie.error("Cannot find camera in vehicle model \"%s\"" % self.locomotive.name)
	return model_cam

#endregion
