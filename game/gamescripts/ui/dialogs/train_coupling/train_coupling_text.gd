## Shared captions for the coupling dialog and its panels.
class_name TrainCouplingText extends RefCounted

static func vehicle_name(vehicle: Vehicle3D) -> String:
	return "%s #%d" % [vehicle.vehicle_obj.veh_type.display_name, vehicle.vehicle_obj.num]

static func pair(first: Vehicle3D, second: Vehicle3D) -> String:
	return "%s ↔ %s" % [vehicle_name(first), vehicle_name(second)]

static func count(amount: int) -> String:
	return "1 vehicle" if amount == 1 else "%d vehicles" % amount

## Adds a row whose metadata is the vehicle; `end` marks a consist end.
static func add_vehicle_row(list: ItemList, vehicle: Vehicle3D, end: String = "") -> int:
	var name_text: String = vehicle_name(vehicle)
	var row: int = list.add_item(name_text if end.is_empty() else name_text + "  ·  " + end)
	list.set_item_metadata(row, vehicle)
	return row
