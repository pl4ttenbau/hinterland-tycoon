@icon("res://assets/icons/icon_station_white.png")
class_name InterchangeData extends GameEntityData

const DEFAULT_INVENTORY_CAPACITY: float = 60.0

@export var interchange_name: String
@export var town_num: int = -1
@export var town_name: String
@export var connected_town: TownData
@export var stops: Array[AbstractStation] = []
@export var connections: StationConnections = StationConnections.new(self)
## Every stop in this interchange accesses this same stock and capacity.
@export var inventory: GoodsInventory

## Catchment is the union of physical stops, not a radius around a centroid.
func reachable_stops(position: Vector3, radius: float = 200.0) -> Array[AbstractStation]:
	var result: Array[AbstractStation] = []
	for stop: AbstractStation in stops:
		if position.distance_squared_to(stop.get("position")) <= radius * radius:
			result.append(stop)
	result.sort_custom(func(a: AbstractStation, b: AbstractStation) -> bool:
		var da: float = position.distance_squared_to(a.get("position"))
		var db: float = position.distance_squared_to(b.get("position"))
		return a.num < b.num if is_equal_approx(da, db) else da < db)
	return result

func _init() -> void:
	super(Enums.EntityTypes.INTERCHANGE)
	inventory = GoodsInventory.new()
	inventory.amount_max = DEFAULT_INVENTORY_CAPACITY
	inventory.storage.max_storage = DEFAULT_INVENTORY_CAPACITY

static func is_valid_num(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) \
		and is_finite(float(value)) and value >= 0 and value == int(value)
