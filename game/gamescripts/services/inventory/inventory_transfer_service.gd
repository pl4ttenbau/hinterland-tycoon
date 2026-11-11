## Shared transactions for manual transfers and automatic route actions.
class_name InventoryTransferService extends RefCounted

const REACH_METRES: float = 20.0

static func validate(source: InventoryEndpoint, target: InventoryEndpoint, stack: InventoryStack, amount: float) -> String:
	var error: String = validate_access(source, target)
	if not error.is_empty():
		return error
	error = _validate_stock(source, stack, amount)
	if not error.is_empty():
		return error
	if completes_passenger_trip(target, stack):
		return ""
	if not target.component().accepts(stack.good_key):
		return "The destination cannot carry this resource category."
	if target.component().free_capacity() + 0.00001 < amount:
		return "There is not enough free capacity."
	return ""

## Physical access is also required for disembarking passengers, even though
## their completed trip does not consume any destination inventory capacity.
static func validate_access(source: InventoryEndpoint, target: InventoryEndpoint) -> String:
	if source == null or target == null or not source.available() or not target.available():
		return "Choose two available inventories."
	if source.inventory() == target.inventory():
		return "Choose two different inventories."
	if not source.position().is_finite() or not target.position().is_finite():
		return "An inventory access point is no longer available."
	if source.position().distance_to(target.position()) > REACH_METRES:
		return "Inventories are too far apart (maximum 20 m)."
	return ""

static func _validate_stock(source: InventoryEndpoint, stack: InventoryStack, amount: float) -> String:
	if stack == null or not is_finite(amount) or amount <= 0:
		return "Choose a resource and a positive quantity."
	var good: BaseGoodsType = GameTypes.resource_types.get(stack.good_key)
	if good == null or (not good.is_passenger() and stack.destination_interchange != -1) or stack.destination_interchange < -1:
		return "Invalid resource or passenger destination."
	if good.is_passenger() and not is_equal_approx(amount, roundf(amount)):
		return "Passengers must be transferred in whole numbers."
	if source.inventory().stack_amount(stack.good_key, stack.destination_interchange) < amount:
		return "There is not enough stock in that group."
	return ""

## Compare the actual shared stock so every access point at the destination
## completes the trip, regardless of which physical stop the vehicle reached.
static func completes_passenger_trip(target: InventoryEndpoint, stack: InventoryStack) -> bool:
	if target == null or stack == null or stack.destination_interchange < 0 or not is_instance_valid(Managers.interchanges):
		return false
	var destination: InterchangeData = Managers.interchanges.by_num.get(stack.destination_interchange)
	return destination != null and destination.inventory != null and target.inventory() == destination.inventory

static func maximum(source: InventoryEndpoint, target: InventoryEndpoint, stack: InventoryStack) -> float:
	if source == null or target == null or stack == null or not source.available() or not target.available():
		return 0
	var amount: float = source.inventory().stack_amount(stack.good_key, stack.destination_interchange)
	if not completes_passenger_trip(target, stack):
		amount = minf(amount, target.component().free_capacity())
	var good: BaseGoodsType = GameTypes.resource_types.get(stack.good_key)
	if good != null and good.is_passenger():
		amount = floorf(amount)
	return amount if validate(source, target, stack, amount).is_empty() else 0.0

## Synchronous mutation, then signals: every observer sees both sides after the transfer.
static func transfer(source: InventoryEndpoint, target: InventoryEndpoint, stack: InventoryStack, amount: float) -> String:
	var error: String = validate(source, target, stack, amount)
	if not error.is_empty():
		return error
	var from: GoodsInventory = source.inventory()
	if completes_passenger_trip(target, stack):
		return "" if from.change_stack(stack.good_key, stack.destination_interchange, -amount) else "Passenger stock changed before arrival."
	var to: GoodsInventory = target.inventory()
	if not from.change_stack(stack.good_key, stack.destination_interchange, -amount, false):
		return "Source inventory changed; select the resource again."
	if not to.change_stack(stack.good_key, stack.destination_interchange, amount, false):
		from.change_stack(stack.good_key, stack.destination_interchange, amount, false)
		return "The destination rejected the transfer."
	from.goods_change.emit()
	to.goods_change.emit()
	return ""
