@icon("res://assets/icons/icon_gears_white.png")
class_name BaseEntityClickHandler extends AbstractClickHandler

static var INDUSTRY_DIAG_PATH = "res://scenes/ui/dialogs/industry_dialog/industry_dialog.tscn"
const STATION_DIALOG_PATH = "res://scenes/ui/dialogs/station_info/station_info_dialog.tscn"

func handle_click(entity_collider: Node3D) -> bool:
	if entity_collider is RoadVehicle3D:
		Managers.vehicles.enter_road_vehicle(entity_collider)
		stop_input()
		return true
	#if UiState.ui_mode != Enums.UiMode.WALKING:
	#	return false
	if !entity_collider || !entity_collider is ClickableCollider: 
		return false
	if entity_collider is VehicleCollider:
		return self._on_vehicle_clicked(entity_collider)
	if entity_collider is RailForkCollider:
		return _on_rail_fork_click(entity_collider)
	if entity_collider is RailDepotCollider:
		return self._on_rail_depot_clicked(entity_collider)
	if entity_collider is RoadDepotCollider:
		return self._on_road_depot_clicked(entity_collider)
	if entity_collider is IndustryCollider:
		return self._on_industry_click(entity_collider)
	if entity_collider is StationCollider:
		return _on_station_click(entity_collider)
	if entity_collider is ClickableCollider:
		return self._on_other_clickable_collider_click(entity_collider)
	return false

## == ENTITY CLICKS ==
func _on_industry_click(collider: IndustryCollider) -> bool:
	var industry_view: Industry3D = collider.outer_industry
	if not is_instance_valid(industry_view) or industry_view.industry == null or UiState.current_diag != null:
		return false
	var dialog: IndustryDialog = load(INDUSTRY_DIAG_PATH).instantiate()
	dialog.industry_view = industry_view
	get_tree().root.add_child(dialog)
	stop_input()
	return true

func _on_station_click(collider: StationCollider) -> bool:
	var stop: AbstractStation = collider.get_stop()
	if stop == null or UiState.current_diag != null:
		return false
	var dialog = load(STATION_DIALOG_PATH).instantiate()
	dialog.stop = stop
	get_tree().root.add_child(dialog)
	stop_input()
	return true
	
func _on_rail_fork_click(fork_collider: RailForkCollider) -> bool:
	var fork: NewRailForkData = fork_collider.get_fork()
	if fork:
		fork.switch()
	self.stop_input()
	return true
	
func _on_vehicle_clicked(veh_collider: VehicleCollider) -> bool:
	var veh3d: Vehicle3D = veh_collider.vehicle3d
	Managers.vehicles.enter_vehicle(veh3d)
	return true

func _on_rail_depot_clicked(depot_collider: RailDepotCollider) -> bool:
	if depot_collider.depot_obj:
		var depot_num: int = depot_collider.depot_obj.num
		SignalBus.request_spawn_action.emit(depot_num)
		return true
	return false

func _on_road_depot_clicked(depot_collider: RoadDepotCollider) -> bool:
	if depot_collider.depot_obj:
		SignalBus.request_road_vehicle_spawn.emit(depot_collider.depot_obj)
		stop_input()
		return true
	return false

func _on_other_clickable_collider_click(clickable_collider: ClickableCollider) -> bool:
	var c_ref: ClickRef = clickable_collider.get_click_ref()
	SignalBus.collider_click.emit(c_ref)
	if c_ref.get_type_str():
		Loggie.info("Click %s %d" % [c_ref.get_type_str(), c_ref.entity_num])
	self.stop_input()
	return true

func stop_input():
	get_viewport().set_input_as_handled()
