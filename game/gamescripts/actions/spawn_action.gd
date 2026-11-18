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
	diag_instance.purchase = spawn_train
	get_tree().root.add_child(diag_instance)
	return diag_instance

## Return an error to keep the purchase dialog open when the order is rejected.
func spawn_train(spawn_dto: TrainVehicleListDto) -> String:
	if not is_instance_valid(Managers.vehicles) or not is_instance_valid(Managers.rails):
		return "Train purchasing is unavailable."
	var depot := RailDepotData.get_by_num(self.last_clicked_depot_num)
	if depot == null or depot.track == null or depot.track.nodes.is_empty() \
			or depot.get_depot_rail_node() == null:
		return "This depot has no valid track endpoint."
	var price: int = spawn_dto.purchase_price()
	if price < 0:
		return "Choose a train with a known purchase price."
	for row: TrainVehicleDto in spawn_dto.rows:
		var type := GameTypes.get_veh_type(row.veh_type_key) as RailVehicleTypeData
		if type.usable_infr == null or not InfrType.rail_gauges_compatible(depot.track.infr_type_key, type.usable_infr.subtype):
			return "%s is incompatible with the depot track gauge." % type.display_name
		if not ResourceLoader.exists(type.model_scene_path, "PackedScene"):
			return "%s is unavailable." % type.display_name
	var company := CompanyData.current()
	if company != null and not company.spend(price):
		return company.spending_error(price)
	var start_pos := self.build_start_pos_dto(depot)
	var train := Managers.vehicles.spawn_train(spawn_dto.rows[0].veh_type_key, start_pos)
	for index: int in range(1, spawn_dto.rows.size()):
		train.spawn_wagon(VehicleData.of(spawn_dto.rows[index].veh_type_key))
	Loggie.info("Spawned new vehicle in direction: %s" % start_pos.dir)
	train.movement.place_vehicles()
	train.movement.start_rollout(train.length_in_m() + TRAIN_DEPOT_CLEARANCE_METRES)
	return ""


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

#endregion
