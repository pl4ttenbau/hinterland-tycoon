## Initial purchase-price balance, in fictional game DM. No transactions are made here.
class_name RailVehiclePricing extends Resource

@export_group("Locomotives")
@export_range(0.0, 1000000.0) var locomotive_base: float = 20000.0
@export_range(0.0, 10000.0) var price_per_kw: float = 250.0
@export_range(0.0, 10000.0) var price_per_kn: float = 1000.0
## Temporary estimate using total empty mass; driven axle weights are not catalogued.
@export_range(0.01, 1.0) var estimated_adhesion: float = 0.25

@export_group("Transport capacity")
@export_range(0.0, 1000000.0) var wagon_base: float = 2000.0
@export_range(0.0, 10000.0) var price_per_capacity_unit: float = 300.0

@export_group("Speed and rounding")
@export_range(0.0, 10.0) var speed_base_multiplier: float = 0.75
@export_range(1.0, 1000.0) var speed_reference_kmh: float = 160.0
@export_range(1, 10000) var rounding_step: int = 100

## Returns null when the necessary specifications are unknown, never a free vehicle.
func price_for(vehicle: VehicleTypeData) -> Variant:
	if vehicle == null or not _positive_number(vehicle.max_speed_kmh):
		return null
	var subtotal: float
	if vehicle.has_motor:
		var strength: Variant = tractive_effort_for(vehicle)
		if not _positive_number(vehicle.motor_power_kw) or strength == null:
			return null
		subtotal = locomotive_base + price_per_kw * float(vehicle.motor_power_kw) \
			+ price_per_kn * float(strength)
		# Railcars pay for their transport capability as well as their motor.
		if vehicle.capacity != null:
			subtotal += price_per_capacity_unit * vehicle.capacity.amount
	else:
		if vehicle.capacity == null:
			return null
		subtotal = wagon_base + price_per_capacity_unit * vehicle.capacity.amount
	var speed_multiplier: float = speed_base_multiplier + float(vehicle.max_speed_kmh) / speed_reference_kmh
	return maxi(rounding_step, int(ceil(subtotal * speed_multiplier / rounding_step)) * rounding_step)

func tractive_effort_for(vehicle: VehicleTypeData) -> Variant:
	if vehicle == null or not vehicle.has_motor:
		return null
	if vehicle.tractive_effort_kn != null:
		return float(vehicle.tractive_effort_kn) if _positive_number(vehicle.tractive_effort_kn) else null
	if not _positive_number(vehicle.mass_tonnes):
		return null
	# Tonnes * m/s² gives kN. This is a balancing estimate, not a vehicle specification.
	return float(vehicle.mass_tonnes) * 9.81 * estimated_adhesion

func uses_estimated_strength(vehicle: VehicleTypeData) -> bool:
	return vehicle != null and vehicle.has_motor and vehicle.tractive_effort_kn == null \
		and tractive_effort_for(vehicle) != null

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0
