## Shared definition for a road vehicle model, separate from its future movement state.
class_name RoadVehicleTypeData extends VehicleTypeData

const PRICING = preload("res://game/jsondata/road_vehicle_pricing.tres")

func get_purchase_price() -> Variant:
	return purchase_price if purchase_price != null else PRICING.price_for(self)

## Unspecified physical values stay null, rather than becoming zero.
## Dimensions in the initial catalog describe the model's geometry in world metres.
var width_metres: Variant = null
var height_metres: Variant = null
## Physical load limit, independent of the game's category-based cargo unit counts.
var payload_tonnes: Variant = null
