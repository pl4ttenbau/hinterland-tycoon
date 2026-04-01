@icon("res://assets/icons/icon_gears_white.png")
class_name BaseEntityClickHandler extends AbstractClickHandler

static var INDUSTRY_DIAG_PATH = "res://scenes/ui/dialogs/industry_dialog/industry_dialog.tscn"

func handle_click(entity_collider: Node3D) -> bool:
	#if UiState.ui_mode != Enums.UiMode.WALKING:
	#	return false
	if !entity_collider || !entity_collider is ClickableCollider: 
		return false
	if entity_collider is VehicleCollider:
		return self._on_vehicle_clicked(entity_collider)
	if entity_collider is RailForkCollider:
		return _on_rail_fork_click(entity_collider)
	if entity_collider is DepotCollider:
		return self._on_depot_clicked(entity_collider)
	if entity_collider is IndustryCollider:
		return self._on_industry_click(entity_collider)
	if entity_collider is ClickableCollider:
		return self._on_other_clickable_collider_click(entity_collider)
	return false

## == ENTITY CLICKS ==
func _on_industry_click(c_ref: IndustryCollider):
	var ind_num: int = c_ref.get_click_ref().entity_num
	var clicked_ind: IndustryData = IndustryData.get_by_num(ind_num)
	# open diag
	var diag_scene: PackedScene = load(INDUSTRY_DIAG_PATH)
	# open industry dialog
	var instance: IndustryDialog = diag_scene.instantiate()
	instance.industry = clicked_ind
	$/root.add_child(instance)
	# stop event handling & return handled as true
	self.stop_input()
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

func _on_depot_clicked(depot_collider: DepotCollider) -> bool:
	if depot_collider.depot_obj:
		var depot_num: int = depot_collider.depot_obj.num
		SignalBus.request_spawn_action.emit(depot_num)
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
