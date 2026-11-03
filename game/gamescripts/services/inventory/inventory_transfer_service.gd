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
	if good == null or (not good.is_passenger() and stack.destination_stop != -1) or stack.destination_stop < -1:
		return "Invalid resource or passenger destination."
	if good.is_passenger() and not is_equal_approx(amount, roundf(amount)):
		return "Passengers must be transferred in whole numbers."
	if source.inventory().stack_amount(stack.good_key, stack.destination_stop) < amount:
		return "There is not enough stock in that group."
	return ""

## Completing a trip removes exactly the chosen destination batch from the
## vehicle. Passengers never re-enter the waiting stock at their own destination.
static func complete_passenger_trip(source: InventoryEndpoint, target: InventoryEndpoint,
		stack: InventoryStack, amount: float, arrival_stop: int) -> String:
	var error: String = validate_access(source, target)
	if not error.is_empty():
		return error
	error = _validate_stock(source, stack, amount)
	if not error.is_empty():
		return error
	var good: BaseGoodsType = GameTypes.resource_types.get(stack.good_key)
	if not good.is_passenger() or arrival_stop < 0 or stack.destination_stop != arrival_stop:
		return "Passengers can only finish their trip at their own destination stop."
	return "" if source.inventory().change_stack(stack.good_key, stack.destination_stop, -amount) else "Passenger stock changed before arrival."

static func maximum(source: InventoryEndpoint, target: InventoryEndpoint, stack: InventoryStack) -> float:
	if source == null or target == null or stack == null or not source.available() or not target.available():
		return 0
	var amount: float = minf(source.inventory().stack_amount(stack.good_key, stack.destination_stop), target.component().free_capacity())
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
	var to: GoodsInventory = target.inventory()
	if not from.change_stack(stack.good_key, stack.destination_stop, -amount, false):
		return "Source inventory changed; select the resource again."
	if not to.change_stack(stack.good_key, stack.destination_stop, amount, false):
		from.change_stack(stack.good_key, stack.destination_stop, amount, false)
		return "The destination rejected the transfer."
	from.goods_change.emit()
	to.goods_change.emit()
	return ""
