## Initial balance for powered road vehicles, in fictional game DM.
class_name RoadVehiclePricing extends Resource

@export_range(0.0, 1000000.0) var vehicle_base: float = 3000.0
@export_range(0.0, 10000.0) var price_per_kw: float = 100.0
## Uses game transport units, not physical payload tonnes.
@export_range(0.0, 10000.0) var price_per_capacity_unit: float = 500.0
@export_range(0.0, 10.0) var speed_base_multiplier: float = 0.75
@export_range(1.0, 1000.0) var speed_reference_kmh: float = 160.0
@export_range(1, 10000) var rounding_step: int = 100

## Unknown operating specs remain unpriced. Trailer pricing is not defined yet.
func price_for(vehicle: VehicleTypeData) -> Variant:
	if vehicle == null or not vehicle.has_motor or vehicle.capacity == null:
		return null
	if not _positive_number(vehicle.max_speed_kmh) or not _positive_number(vehicle.motor_power_kw):
		return null
	var subtotal: float = vehicle_base + price_per_kw * float(vehicle.motor_power_kw) \
		+ price_per_capacity_unit * vehicle.capacity.amount
	var speed_multiplier: float = speed_base_multiplier + float(vehicle.max_speed_kmh) / speed_reference_kmh
	return maxi(rounding_step, int(ceil(subtotal * speed_multiplier / rounding_step)) * rounding_step)

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0
