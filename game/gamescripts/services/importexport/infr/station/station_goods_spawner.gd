@icon("res://assets/icons/icon_good_white.png")
class_name StationGoodsSpawner extends Node

@export var has_map_selected: bool = false

var passenger_planner := PassengerTripPlanner.new()

func _ready() -> void:
	$SpawnPassengersTimer.timeout.connect(_on_passenger_spawn_tick)

## One attempt per existing timer tick. Failed plans create no passenger and are
## not retried, so unconnected destinations retain their intended discard chance.
func spawn_rnd_passenger() -> bool:
	if not has_map_selected or GlobalState.loaded_map == null:
		return false
	passenger_planner.refresh(GlobalState.res_bld_containers)
	return spawn_passenger(passenger_planner.plan())

## Materialize the resolved trip directly in the origin stop's inventory. There
## is no temporary world object to clean up, and no destination-less fallback.
func spawn_passenger(request: PassengerSpawnRequest) -> bool:
	if request == null or request.origin_stop == null or request.destination_stop == null:
		return false
	if request.origin_stop.num < 0 or request.destination_stop.num < 0 \
			or request.origin_stop.num == request.destination_stop.num:
		return false
	var origin: InventoryEntity3D = request.origin_stop.get_inventory_view()
	var destination: InventoryEntity3D = request.destination_stop.get_inventory_view()
	if not is_instance_valid(origin) or not is_instance_valid(destination) \
			or not origin.is_inside_tree() or not destination.is_inside_tree():
		return false
	var component: InventoryContainer = InventoryContainer.find_on(origin)
	if component == null or not component.accepts(&"passenger") or component.free_capacity() < 1:
		return false
	# Destination occupancy does not block travel demand; only the waiting room
	# where the passenger actually appears needs capacity for this spawn.
	return component.get_inventory().change_stack(&"passenger", request.destination_stop.num, 1)

func _on_passenger_spawn_tick() -> void:
	spawn_rnd_passenger()

func _on_map_selected(_selected_map: MapData) -> void:
	has_map_selected = true
