class_name SpawnAction extends BaseAction

const COMPOSE_TRAIN_DIAG_SCENE = "res://scenes/ui/dialogs/train_composition/train_composition_dialog.tscn"
const ROAD_SPAWN_DIALOG = preload("res://game/gamescripts/ui/dialogs/road_vehicle_spawn/road_vehicle_spawn_dialog.gd")
const TRAIN_DEPOT_CLEARANCE_METRES: float = 10.0

@export var last_clicked_depot_num: int = -1

func _enter_tree() -> void:
	SignalBus.request_spawn_action.connect(Callable(self, "_on_spawn_action_request"))
	SignalBus.request_road_vehicle_spawn.connect(_on_road_vehicle_spawn_requested)

## Road depots use a separate request so rail and road IDs may safely overlap.
func _on_road_vehicle_spawn_requested(depot: RoadDepotData) -> void:
	if UiState.current_diag != null:
		return
	var dialog: GameDialog = ROAD_SPAWN_DIALOG.create(depot)
	get_tree().root.add_child(dialog)

func on_trigger():
	super.on_trigger()
	if UiState.current_diag == null:
		show_compose_train_diag()

func show_compose_train_diag() -> TrainCompositionDialog:
	var diag_scene: PackedScene = load(COMPOSE_TRAIN_DIAG_SCENE)
	var diag_instance: TrainCompositionDialog = diag_scene.instantiate()
	var depot: RailDepotData = RailDepotData.get_by_num(self.last_clicked_depot_num)
	if depot != null:
		(diag_instance.get_node("%AddableVehiclesList") as VehicleListUi).depot_track = depot.track
	diag_instance.closed.connect(_on_train_composition_closed, CONNECT_ONE_SHOT)
	get_tree().root.add_child(diag_instance)
	return diag_instance

func spawn_train(spawn_dto: TrainVehicleListDto):
	var depot_obj := RailDepotData.get_by_num(self.last_clicked_depot_num)
	if depot_obj and depot_obj.track and not spawn_dto.rows.is_empty():
		for row: TrainVehicleDto in spawn_dto.rows:
			var vehicle_type := GameTypes.get_veh_type(row.veh_type_key) as RailVehicleTypeData
			if vehicle_type == null or not InfrType.rail_gauges_compatible(depot_obj.track.infr_type_key, vehicle_type.usable_infr.subtype):
				push_warning("Cannot spawn %s on the depot's track gauge." % row.veh_type_key)
				return
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
		train3d.movement.place_vehicles()
		train3d.movement.start_rollout(train3d.length_in_m() + TRAIN_DEPOT_CLEARANCE_METRES)
		
func build_start_pos_dto(depot_obj: RailDepotData) -> VehicleStartPos:
	var depot_node_index := depot_obj.get_depot_rail_node().index
	var veh_dir = self.get_veh_dir_from_depot_pos(depot_obj.track_pos)
	return VehicleStartPos.of(depot_obj.track_num, depot_node_index, veh_dir)
		
func get_veh_dir_from_depot_pos(depot_pos: String) -> Enums.PathDirection:
	if depot_pos == "START": return Enums.PathDirection.TRACK_NODES_INCREASE
	return Enums.PathDirection.TRACK_NODES_DECREASE
	
#region Callbacks
func _on_spawn_action_request(depot_num: int):
	Loggie.info("Vehicle Spawning requested at depot %d" % depot_num)
	self.last_clicked_depot_num = depot_num
	self.on_trigger()

## Escape closes with a null result. Only the Spawn button supplies a train.
func _on_train_composition_closed(result: Variant) -> void:
	if result is TrainVehicleListDto:
		spawn_train(result)
#endregion
