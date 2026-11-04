## Execute one stop action through shared inventory transactions. Route driving,
## action ordering and UI editing remain separate from stock-transfer policy.
class_name RoadRouteTransferService extends RefCounted

const MAX_SERVICE_SPEED: float = 0.5

static func execute(vehicle: RoadVehicle3D, point: RoadRoutePoint,
		action: RoadRouteAction, stops: Dictionary) -> RoadRouteTransferResult:
	var result := RoadRouteTransferResult.new()
	result.error = _validate_action(vehicle, point, action, stops)
	if not result.error.is_empty():
		return result
	var stop: AbstractStation = stops[point.target_num]
	var vehicle_end: InventoryEndpoint = InventoryEndpoint.from_node(vehicle)
	var stop_end: InventoryEndpoint = InventoryEndpoint.from_node(stop.get_inventory_view())
	result.error = InventoryTransferService.validate_access(vehicle_end, stop_end)
	if not result.error.is_empty():
		return result
	var source: InventoryEndpoint = stop_end if action.kind == RoadRouteAction.Kind.LOAD else vehicle_end
	var target: InventoryEndpoint = vehicle_end if action.kind == RoadRouteAction.Kind.LOAD else stop_end
	_execute_stacks(source, target, action, stop.num, result)
	return result

## Validate live references as well as the frozen plan: infrastructure or a
## passenger destination may have been removed since the vehicle departed.
static func _validate_action(vehicle: RoadVehicle3D, point: RoadRoutePoint,
		action: RoadRouteAction, stops: Dictionary) -> String:
	if not is_instance_valid(vehicle) or not vehicle.is_inside_tree():
		return "Vehicle is no longer available."
	if vehicle.player_driving or vehicle.linear_velocity.length() > MAX_SERVICE_SPEED:
		return "Stop the vehicle and release manual control before servicing."
	if point == null or point.kind != RoadRoutePoint.Kind.STOP or not stops.get(point.target_num) is RoadStationData:
		return "The transfer stop is no longer available."
	if action == null:
		return "Missing transfer action."
	return action.validate(GameTypes.resource_types, stops, vehicle.vehicle_obj.veh_type.capacity)

## Snapshot rows in stable resource/destination order. Read available quantities
## again for each transfer; change signals may update inventory between rows.
static func _execute_stacks(source: InventoryEndpoint, target: InventoryEndpoint,
		action: RoadRouteAction, stop: int, result: RoadRouteTransferResult) -> void:
	var rows: Array[InventoryStack] = source.inventory().stacks(false)
	rows.append_array(source.inventory().stacks(true))
	for stack: InventoryStack in rows:
		var good: BaseGoodsType = GameTypes.resource_types.get(stack.good_key)
		if not action.matches(good, stack.destination_stop):
			continue
		result.error = _move_stack(source, target, stack, action, stop, result)
		if not result.error.is_empty():
			return

## Loading/unloading is a single best-effort visit, not a wait-until-full order.
## At the exact destination, passengers leave the simulation; elsewhere they
## remain a destination-tagged waiting batch if explicitly unloaded there.
static func _move_stack(source: InventoryEndpoint, target: InventoryEndpoint,
		stack: InventoryStack, action: RoadRouteAction, stop: int, result: RoadRouteTransferResult) -> String:
	var error: String = InventoryTransferService.validate_access(source, target)
	if not error.is_empty():
		return error
	var amount: float = source.inventory().stack_amount(stack.good_key, stack.destination_stop)
	if amount <= 0:
		return ""
	if action.kind == RoadRouteAction.Kind.UNLOAD and stack.destination_stop == stop:
		error = InventoryTransferService.complete_passenger_trip(source, target, stack, amount, stop)
		if error.is_empty():
			result.moved += amount
			result.completed_passengers += amount
		return error
	if not target.component().accepts(stack.good_key):
		return "The destination cannot carry %s." % stack.good_key
	amount = InventoryTransferService.maximum(source, target, stack)
	if amount <= 0:
		return ""
	error = InventoryTransferService.transfer(source, target, stack, amount)
	if error.is_empty():
		result.moved += amount
	return error
