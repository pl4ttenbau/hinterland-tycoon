## An instruction at a route point. Editing this data never transfers inventory.
class_name RoadRouteAction extends Resource

enum Kind { LOAD, UNLOAD }
@export var kind: Kind = Kind.LOAD
@export var goods: Array[StringName] = []
## Exact physical stop IDs, not interchange IDs. Required when selecting passengers.
@export var passenger_targets: Array[int] = []

func validate(catalog: Dictionary, stops: Dictionary, capacity: GoodsCapacity) -> String:
	if kind not in [Kind.LOAD, Kind.UNLOAD] or goods.is_empty():
		return "Choose load/unload and at least one good."
	for key: StringName in goods:
		var good: BaseGoodsType = catalog.get(key)
		if good == null:
			return "Unknown good: %s" % key
		if capacity != null and capacity.goods_cat != good.res_cat:
			return "This vehicle cannot carry %s." % key
		if good.is_passenger() and passenger_targets.is_empty():
			return "Choose at least one physical destination stop for passengers."
	for target: int in passenger_targets:
		if not stops.has(target):
			return "Passenger destination stop %d no longer exists." % target
	return ""

func describe() -> String:
	var description: String = "%s %s" % ["Load" if kind == Kind.LOAD else "Unload", ", ".join(goods)]
	if not passenger_targets.is_empty():
		description += " (passenger targets: %s)" % str(passenger_targets)
	return description

## Future transfers can select destination-specific batches without merging targets.
func matches(good: BaseGoodsType, passenger_target: int = -1) -> bool:
	return good != null and good.key in goods and (not good.is_passenger() or passenger_target in passenger_targets)
