## Shared definition for a road vehicle model, separate from its future movement state.
class_name RoadVehicleTypeData extends VehicleTypeData

const PRICING = preload("res://game/jsondata/road_vehicle_pricing.tres")

func get_purchase_price() -> Variant:
	return purchase_price if purchase_price != null else PRICING.price_for(self)

## Legacy catalog geometry for models that predate RoadVehicleModel3D.
var width_metres: Variant = null
var height_metres: Variant = null
## Distance between the front and rear axles. Null uses the factory estimate.
var wheelbase_metres: Variant = null
## Longitudinal centre of the two axles relative to the vehicle origin. +Z is forward.
var axle_offset_metres: float = 0.0
## Optional correction for legacy model scenes authored with a different forward axis.
var model_yaw_degrees: float = 0.0
## Physical load limit, independent of the game's category-based cargo unit counts.
var payload_tonnes: Variant = null
