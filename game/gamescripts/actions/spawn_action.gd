class_name SpawnAction extends Node

const VEHICLE_SELECT_DIAG_SCENE = "res://scenes/ui/dialogs/select_vehicle_dialog.tscn"

func on_trigger():
	var diag_scene: PackedScene = load(VEHICLE_SELECT_DIAG_SCENE)
	var instance: SelectVehicleDialog = diag_scene.instantiate()
	# connect to signal
	instance.vehicle_spawn_triggered.connect(Callable(self, "_on_vehicle_spawn_pressed"))
	# show dialog
	$/root.add_child(instance)
		
func spawn_vehicle(spawn_dto: VehicleSpawnDto):
	var depot_obj := self.get_depot_by_num(spawn_dto.depot_num)
	if depot_obj:
		var depot_node_index := depot_obj.get_depot_rail_node().index
		var veh_dir = self.get_veh_dir_from_depot_pos(depot_obj.track_pos)
		Loggie.info("Spawn new vehicle in direction: %s" % veh_dir)
		var veh_type_key: String = spawn_dto.vehicle_type_key
		var veh := Managers.vehicles.spawn_vehicle(veh_type_key, depot_obj.track_num, depot_node_index, veh_dir)
		# start
		veh.motor.start()
		
func get_veh_dir_from_depot_pos(depot_pos: String) -> VehicleMotor.Direction:
	if depot_pos == "START": return VehicleMotor.Direction.TRACK_NODES_INCREASE
	return VehicleMotor.Direction.TRACK_NODES_DECREASE

func get_depot_by_num(depot_num: int) -> RailDepotData:
	for depot: RailDepotData in GlobalState.depots:
		if depot.num == depot_num: return depot
	Loggie.warn("Cannot find Depot with num %d" % depot_num)
	return null
	
#region Callbacks
func _on_vehicle_spawn_pressed(spawn_dto: VehicleSpawnDto) -> void:
	Loggie.info("Vehicle spawning btn pressed: %s in depot %s" % [spawn_dto.vehicle_type_key, spawn_dto.depot_num])
	self.spawn_vehicle(spawn_dto)
#endregion
