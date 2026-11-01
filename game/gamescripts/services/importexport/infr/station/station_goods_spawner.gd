@icon("res://assets/icons/icon_good_white.png")
class_name StationGoodsSpawner extends Node

const LOG_SPAWNING: bool = true

@export var has_map_selected: bool = false

func _ready() -> void:
	$SpawnPassengersTimer.timeout.connect(Callable(self, "_on_passenger_spawn_tick"))
	
#region Passengers
func spawn_rnd_passenger():
	if ! self.has_map_selected: return
	if ! GlobalState.loaded_map: return
	if GlobalState.res_bld_containers.is_empty(): return
	var residence: Residence3D = Residence3D.get_random()
	if residence == null or residence.res_bld_obj == null: return
	var data: ResidenceBuildingData = residence.res_bld_obj
	if data.connected_interchange == null: return
	# One passenger per spawn, using the closest reachable physical stop that
	# already has a view. Interchange membership never multiplies the spawn.
	for stop: AbstractStation in data.reachable_stops:
		var view: InventoryEntity3D = stop.get_inventory_view()
		if view != null and view.get_inventory() != null:
			view.get_inventory().add_good_of("passenger")
			return
#endregion

#region Callbacks
func _on_passenger_spawn_tick():
	self.spawn_rnd_passenger()
	
func _on_map_selected(_selected_map: MapData):
	self.has_map_selected = true
#endregion
