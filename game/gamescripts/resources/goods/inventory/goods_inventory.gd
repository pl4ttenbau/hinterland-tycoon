@icon("res://assets/icons/inventory/goods_inventory.svg")
class_name GoodsInventory extends Resource

signal goods_change()

@export var storage: BaseGoodsStorage

@export var amount_used: float
@export var amount_max: float
## Legacy serialized stop IDs, converted once the map stop registry is ready.
@export var passenger_destinations: Dictionary = {}
## Passenger good -> destination interchange ID -> amount.
@export var passenger_interchange_destinations: Dictionary = {}

func _init() -> void:
	self.resource_local_to_scene = true
	# create BaseStorage child if not already done
	if !self.storage:
		self.storage = BaseGoodsStorage.new()
		if self.amount_max && self.amount_max > 0:
			self.storage.max_storage = amount_max
	# connect to change signal
	self.goods_change.connect(Callable(self, "_on_goods_changed"))

#region Add Or Remove
func add_good_of(res_type_key: StringName):
	var amount_dto := GoodsAmount.new(res_type_key, 1)
	self.add_goods_amount(amount_dto)

func add_goods_amount(goods_amount: GoodsAmount) -> bool:
	return goods_amount != null and goods_amount.amount > 0 and change_stack(goods_amount.res_key, -1, goods_amount.amount)

func remove_goods_amount(goods_amount: GoodsAmount) -> bool:
	# Legacy callers have no destination: they may only remove unassigned stock.
	return goods_amount != null and goods_amount.amount > 0 and change_stack(goods_amount.res_key, -1, -goods_amount.amount)
#endregion

#region Getters
func as_goods_amount_list() -> Array[GoodsAmount]:
	var amount_dto_list: Array[GoodsAmount] = []
	for res_key: String in self.storage.get_res_key_list():
		var amount_dto = GoodsAmount.new(res_key, self.get_amount(res_key))
		amount_dto_list.append(amount_dto)
	return amount_dto_list

func get_amount(res_type_key: String) -> float:
	return self.storage.get_amount(res_type_key)
#endregion

#region Amount Checking
func has_any(res_type_key: String) -> bool:
	return self.storage.has_any(res_type_key)
	
func has_enough(amount_dto: GoodsAmount) -> bool:
	if ! amount_dto.res_key: return false
	var amount_left: float = self.get_amount(amount_dto.res_key)
	return amount_left >= amount_dto.amount

func can_take(amount_dto: GoodsAmount):
	var stored_after_added: float = self.storage.current_storage + amount_dto.amount
	return is_finite(amount_dto.amount) and amount_dto.amount > 0 and stored_after_added <= self.amount_max
#endregion

## Select a passenger batch without merging people with different destinations.
func stack_amount(key: StringName, destination: int = -1) -> float:
	_upgrade_passenger_destinations()
	var total: float = storage.get_amount(key)
	var groups: Dictionary = passenger_interchange_destinations.get(key, {})
	if destination >= 0:
		return float(groups.get(destination, 0))
	for count: float in groups.values():
		total -= count
	var legacy_groups: Dictionary = passenger_destinations.get(key, {})
	for count: float in legacy_groups.values():
		total -= count
	return maxf(0, total)

## Low-level stack mutation. TransferService validates both ends before calling it.
## notify=false lets a transaction update both inventories before notifying observers.
func change_stack(key: StringName, destination: int, delta: float, notify: bool = true) -> bool:
	var good: BaseGoodsType = GameTypes.resource_types.get(key)
	if good == null or not is_finite(delta) or destination < -1:
		return false
	if good.is_passenger() and not is_equal_approx(delta, roundf(delta)):
		return false
	if not good.is_passenger() and destination != -1:
		return false
	if delta < 0 and stack_amount(key, destination) < -delta:
		return false
	if good.is_passenger() and destination >= 0:
		_upgrade_passenger_destinations()
		var groups: Dictionary = passenger_interchange_destinations.get(key, {}).duplicate()
		groups[destination] = float(groups.get(destination, 0)) + delta
		if is_zero_approx(groups[destination]):
			groups.erase(destination)
		passenger_interchange_destinations[key] = groups
	storage.change_amount(key, delta)
	if notify:
		goods_change.emit()
	return true

## Generate passenger/cargo rows without changing existing aggregate consumers.
func stacks(passengers: bool) -> Array[InventoryStack]:
	_upgrade_passenger_destinations()
	var result: Array[InventoryStack] = []
	for key: String in storage.get_res_key_list():
		var good: BaseGoodsType = GameTypes.resource_types.get(key)
		if good == null or good.is_passenger() != passengers:
			continue
		if passengers:
			var groups: Dictionary = passenger_interchange_destinations.get(key, {})
			for destination: int in groups:
				if float(groups[destination]) > 0:
					result.append(InventoryStack.new(key, groups[destination], destination))
		var unassigned: float = stack_amount(key)
		if unassigned > 0:
			result.append(InventoryStack.new(key, unassigned))
	result.sort_custom(func(a: InventoryStack, b: InventoryStack):
		# Sort the resource names, rather than StringName's interned identifiers.
		return str(a.good_key) < str(b.good_key) if a.good_key != b.good_key else a.destination_interchange < b.destination_interchange)
	return result

## Old stop IDs can overlap interchange IDs. Translate through the stop catalog
## and merge destinations that now share one interchange. Passengers whose old
## stop is missing remain in the aggregate as unassigned.
func _upgrade_passenger_destinations() -> void:
	if passenger_destinations.is_empty() or not is_instance_valid(Managers.interchanges):
		return
	var catalog: InterchangesLoader = Managers.interchanges
	if not catalog.is_loaded or catalog.stops_by_num.size() < catalog.stop_definitions.size():
		return
	for key: StringName in passenger_destinations:
		var old_groups: Dictionary = passenger_destinations[key]
		var groups: Dictionary = passenger_interchange_destinations.get(key, {}).duplicate()
		for stop_id: int in old_groups:
			var stop: AbstractStation = catalog.stops_by_num.get(stop_id)
			if stop == null or stop.interchange == null:
				continue
			var destination: int = stop.interchange.num
			groups[destination] = float(groups.get(destination, 0.0)) + float(old_groups[stop_id])
		passenger_interchange_destinations[key] = groups
	passenger_destinations = {}

#region Callbacks
func _on_goods_changed():
	if !self.storage:
		Loggie.error("BaseResourceStorage not added as a child!")
		return
	self.amount_used = self.storage.current_storage
#endregion
