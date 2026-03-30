class_name SpawnAction extends Node

const VEHICLE_SELECT_DIAG_SCENE = "res://scenes/ui/dialogs/select_vehicle/select_vehicle_dialog.tscn"
const COMPOSE_TRAIN_DIAG_SCENE = "res://scenes/ui/dialogs/train_composition/train_composition_dialog.tscn"

func on_trigger():
	var diag_instance: TrainCompositionDialog = self.show_compose_train_diag()
	diag_instance.before_closed.connect(Callable(self, "_on_before_diag_closed"))

func show_compose_train_diag() -> TrainCompositionDialog:
	var diag_scene: PackedScene = load(COMPOSE_TRAIN_DIAG_SCENE)
	var diag_instance: TrainCompositionDialog = diag_scene.instantiate()
	$/root.add_child(diag_instance)
	diag_instance.show_dialog()
	return diag_instance

func spawn_train(spawn_dto: TrainVehicleList):
	var depot_obj := self.get_depot_by_num(spawn_dto.depot_num)
	if depot_obj:
		var loco_type_key: String = spawn_dto.rows[0].veh_type_key
		var start_pos := self.build_start_pos_dto(depot_obj)
		var train3d := Managers.vehicles.spawn_train(loco_type_key, start_pos)
		var veh_index: int = 0
		for train_veh: TrainVehicleDto in spawn_dto.rows:
			if ! veh_index == 0:
				# temporary: spawn with wagon
				var wagon_veh_data := VehicleData.of(train_veh.veh_type_key)
				train3d.spawn_wagon(wagon_veh_data)
			veh_index += 1
		Loggie.info("Spawned new vehicle in direction: %s" % start_pos.dir)
		# start
		train3d.motor.start()
		
func build_start_pos_dto(depot_obj: RailDepotData) -> VehicleStartPos:
	var depot_node_index := depot_obj.get_depot_rail_node().index
	var veh_dir = self.get_veh_dir_from_depot_pos(depot_obj.track_pos)
	return VehicleStartPos.of(depot_obj.track_num, depot_node_index, veh_dir)
		
func get_veh_dir_from_depot_pos(depot_pos: String) -> Enums.PathDirection:
	if depot_pos == "START": return Enums.PathDirection.TRACK_NODES_INCREASE
	return Enums.PathDirection.TRACK_NODES_DECREASE

func get_depot_by_num(depot_num: int) -> RailDepotData:
	for depot: RailDepotData in GlobalState.depots:
		if depot.num == depot_num: return depot
	Loggie.warn("Cannot find Depot with num %d" % depot_num)
	return null
	
#region Callbacks
func _on_vehicle_spawn_pressed(train_vehicles: TrainVehicleList, depot_num: int) -> void:
	# var loco_type_key: String = train_vehicles.rows[0].veh_type_key
	# Loggie.info("Vehicle spawning btn pressed: %s in depot %s" % [loco_type_key, depot_num])
	# self.spawn_train(train_vehicles)
	pass

func _on_before_diag_closed(diag_result):
	if !diag_result is TrainVehicleList:
		Loggie.error("Wrong Diag result when closing ComposeTrainDialog")
		return
	var spawn_dto: TrainVehicleList = diag_result as TrainVehicleList
	self.spawn_train(spawn_dto)
#endregion
