## An instruction at a route point. Editing this data never transfers inventory.
class_name RoadRouteAction extends Resource

enum Kind { LOAD, UNLOAD }
@export var kind: Kind = Kind.LOAD
@export var goods: Array[StringName] = []
## Legacy stop IDs from previously saved actions.
@export var passenger_targets: Array[int] = []
@export var passenger_interchange_targets: Array[int] = []

func validate(catalog: Dictionary, stops: Dictionary, capacity: GoodsCapacity) -> String:
	if kind not in [Kind.LOAD, Kind.UNLOAD] or goods.is_empty():
		return "Choose load/unload and at least one good."
	for key: StringName in goods:
		var good: BaseGoodsType = catalog.get(key)
		if good == null:
			return "Unknown good: %s" % key
		if capacity != null and capacity.goods_cat != good.res_cat:
			return "This vehicle cannot carry %s." % key
		if good.is_passenger() and passenger_targets.is_empty() and passenger_interchange_targets.is_empty():
			return "Choose at least one destination interchange for passengers."
	for target: int in passenger_targets:
		var stop: AbstractStation = stops.get(target)
		if stop == null or stop.interchange == null:
			return "Passenger destination stop %d has no interchange." % target
	var destinations: Dictionary[int, InterchangeData] = available_destinations(stops)
	for target: int in passenger_interchange_targets:
		if not destinations.has(target):
			return "Passenger destination interchange %d is unavailable." % target
	return ""

func describe() -> String:
	var description: String = "%s %s" % ["Load" if kind == Kind.LOAD else "Unload", ", ".join(goods)]
	if not passenger_interchange_targets.is_empty():
		description += " (interchanges: %s)" % str(passenger_interchange_targets)
	if not passenger_targets.is_empty():
		description += " (saved stop targets: %s)" % str(passenger_targets)
	return description

## A saved stop target resolves through that stop's parent, even when the stop
## and interchange catalogs use the same numeric IDs for different places.
func destination_ids(stops: Dictionary) -> Array[int]:
	var destinations: Array[int] = passenger_interchange_targets.duplicate()
	for stop_id: int in passenger_targets:
		var stop: AbstractStation = stops.get(stop_id)
		if stop != null and stop.interchange != null and not destinations.has(stop.interchange.num):
			destinations.append(stop.interchange.num)
	return destinations

static func available_destinations(stops: Dictionary) -> Dictionary[int, InterchangeData]:
	var destinations: Dictionary[int, InterchangeData] = {}
	for stop: AbstractStation in stops.values():
		if stop != null and stop.interchange != null:
			destinations[stop.interchange.num] = stop.interchange
	return destinations

func matches(good: BaseGoodsType, passenger_target: int, destinations: Array[int]) -> bool:
	return good != null and good.key in goods and (not good.is_passenger() or passenger_target in destinations)
