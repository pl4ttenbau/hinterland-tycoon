@icon("res://assets/icons/nodes_3d/icon_locomotive.svg")
class_name Train3D extends InventoryEntity3D

const EMPTY_SCENE_PATH = "res://scenes/subscenes/vehicle/train_3d.tscn"

signal on_vehicle_added(veh3d: RailVehicle3D)

static var _last_train_num: int = 0

@export var num: int

@export var train_obj: TrainData:
	get(): return self.entity as TrainData
	set(value):
		self.entity = value

@export var vehicles: Array[RailVehicle3D] = []
@export var locomotive: RailVehicle3D

## The train scene wires its movement controller before factory setup or scene insertion.
@export var movement: TrainMovement

@export var current_station: StationCatchmentArea

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
	self.add_vehicle(RailVehicle3D.of_vehicle_obj(veh_data, self), true)
	# set starting node
	self.movement.last_node = start_pos.track_obj.get_rail_node(start_pos.node_index)

func spawn_wagon(veh_data: VehicleData):
	self.train_obj.append_vehicle(veh_data)
	self.add_vehicle(RailVehicle3D.of_vehicle_obj(veh_data, self), false)

func add_vehicle(veh3d: RailVehicle3D, is_locomotive: bool = false):
	veh3d.train3d = self
	var num_in_train: int = self.vehicles.size()
	veh3d.num_in_train = num_in_train
	self.vehicles.append(veh3d)
	if is_locomotive: 
		self.locomotive = veh3d
	veh3d.offset_to_first = vehicles[num_in_train - 1].offset_to_first \
		+ veh3d.calc_offset_to_previous(num_in_train) if num_in_train > 0 else 0.0
	$TrainVehicles.add_child(veh3d)
	self.on_vehicle_added.emit(veh3d)

## Retain the actual vehicles, including their models, cameras and collision bodies.
func replace_consist(ordered: Array[RailVehicle3D]) -> void:
	vehicles = ordered
	if locomotive not in vehicles:
		locomotive = null
		for vehicle: RailVehicle3D in vehicles:
			if vehicle.vehicle_obj.veh_type.is_locomotive():
				locomotive = vehicle
				break
	var data: Array[VehicleData] = []
	var container: Node = $TrainVehicles
	var offset: float = 0.0
	for index: int in range(vehicles.size()):
		var vehicle: RailVehicle3D = vehicles[index]
		vehicle.num_in_train = index
		if vehicle.get_parent() != container:
			var pose: Transform3D = vehicle.global_transform
			vehicle.get_parent().remove_child(vehicle)
			vehicle.train3d = self
			container.add_child(vehicle, true)
			vehicle.global_transform = pose
		offset += vehicle.calc_offset_to_previous(index)
		vehicle.offset_to_first = offset
		container.move_child(vehicle, index)
		data.append(vehicle.vehicle_obj)
	var engine: VehicleData = locomotive.vehicle_obj if locomotive != null else null
	train_obj.replace_consist(data, engine)

#endregion

#region Size Getters
func count() -> int:
	return self.vehicles.size()

func length_in_m() -> float:
	var total_length: float = 0.0
	for attached_veh: RailVehicle3D in self.vehicles:
		if attached_veh.vehicle_obj && attached_veh.vehicle_obj.veh_type:
			total_length += attached_veh.vehicle_obj.veh_type.length_metres
	return total_length
#endregion

#region Node Children Getters
func get_static_body() -> StaticBody3D: return self.get_child(0)

func get_cam() -> Camera3D:
	if not is_instance_valid(locomotive):
		return null
	var model_cam: Camera3D = self.locomotive.find_child("Camera3D", true)
	if !model_cam: Loggie.error("Cannot find camera in vehicle model \"%s\"" % self.locomotive.name)
	return model_cam

#endregion
