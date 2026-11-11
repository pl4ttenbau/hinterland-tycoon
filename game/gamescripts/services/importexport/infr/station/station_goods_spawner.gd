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

## Add one passenger to origin stock, tagged with the destination interchange.
func spawn_passenger(request: PassengerSpawnRequest) -> bool:
	if request == null or request.origin_stop == null or request.destination_interchange == null:
		return false
	var destination: InterchangeData = request.destination_interchange
	if request.origin_stop.num < 0 or request.origin_stop.interchange == null or destination.num < 0:
		return false
	if request.origin_stop.interchange.num == destination.num:
		return false
	var origin: InventoryEntity3D = request.origin_stop.get_inventory_view()
	if not is_instance_valid(origin) or not origin.is_inside_tree() or not _has_live_stop(destination):
		return false
	var component: InventoryContainer = InventoryContainer.find_on(origin)
	if component == null or not component.accepts(&"passenger") or component.free_capacity() < 1:
		return false
	return component.get_inventory().change_stack(&"passenger", destination.num, 1)

func _has_live_stop(interchange: InterchangeData) -> bool:
	for stop: AbstractStation in interchange.stops:
		var view: InventoryEntity3D = stop.get_inventory_view()
		if is_instance_valid(view) and view.is_inside_tree():
			return true
	return false

func _on_passenger_spawn_tick() -> void:
	if has_map_selected and is_instance_valid(Managers.interchanges):
		_remove_arrived_passengers()
	spawn_rnd_passenger()

## Older unloads and trips between stops in one interchange could leave
## passengers waiting at their destination. Clear those batches in place.
func _remove_arrived_passengers() -> void:
	for interchange: InterchangeData in Managers.interchanges.interchanges:
		var stock: GoodsInventory = interchange.inventory
		if stock == null:
			continue
		var changed: bool = false
		for batch: InventoryStack in stock.stacks(true):
			if batch.destination_interchange == interchange.num:
				if stock.change_stack(batch.good_key, interchange.num, -batch.amount, false):
					changed = true
		if changed:
			stock.goods_change.emit()

func _on_map_selected(_selected_map: MapData) -> void:
	has_map_selected = true
