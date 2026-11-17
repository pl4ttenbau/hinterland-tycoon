## Physical limits of one consist, derived from its vehicles' catalog data.
## Units: metres, seconds, kilograms, newtons and watts.
class_name TrainDynamics extends RefCounted

## Used when no vehicle in the consist states a maximum speed (former fixed top speed).
const LEGACY_MAX_SPEED_MPS: float = 6.0
## Mass assumed for a vehicle whose catalog entry has no mass.
const DEFAULT_VEHICLE_MASS_TONNES: float = 10.0
## Drivers do not use full adhesion; this also keeps light consists from leaping away.
const MAX_TRACTION_ACCELERATION: float = 1.0
## A powered vehicle without power or tractive effort data still accelerates gently.
const FALLBACK_ACCELERATION: float = 0.3
## Power limits force as P / v; below this speed the tractive effort limit applies instead.
const MIN_POWER_SPEED_MPS: float = 1.0
## Normal braking: lowering the target speed, and planning stops ahead (buffers, signals).
const SERVICE_DECELERATION: float = 0.5
## Applied by the brake control, or when the train is faster than it can still stop with service braking.
const BRAKE_DECELERATION: float = 1.0

var max_speed_mps: float = LEGACY_MAX_SPEED_MPS
var mass_kg: float = 0.0
var power_w: float = 0.0
var tractive_effort_n: float = 0.0
var has_motor: bool = false
## At least one motor lacks both power and tractive effort data.
var has_unspecified_motor: bool = false

static func of_vehicles(vehicles: Array[Vehicle3D]) -> TrainDynamics:
	var types: Array[VehicleTypeData] = []
	for vehicle: Vehicle3D in vehicles:
		if is_instance_valid(vehicle) and vehicle.vehicle_obj != null and vehicle.vehicle_obj.veh_type != null:
			types.append(vehicle.vehicle_obj.veh_type)
	return of_types(types)

static func of_types(types: Array[VehicleTypeData]) -> TrainDynamics:
	var dynamics := TrainDynamics.new()
	var slowest: float = INF
	for veh_type: VehicleTypeData in types:
		if _positive(veh_type.max_speed_kmh):
			slowest = minf(slowest, float(veh_type.max_speed_kmh) / 3.6)
		dynamics.mass_kg += (float(veh_type.mass_tonnes) if _positive(veh_type.mass_tonnes) else DEFAULT_VEHICLE_MASS_TONNES) * 1000.0
		if not veh_type.has_motor:
			continue
		dynamics.has_motor = true
		var power_known: bool = _positive(veh_type.motor_power_kw)
		if power_known:
			dynamics.power_w += float(veh_type.motor_power_kw) * 1000.0
		## Shares the pricing estimate: authored effort, otherwise adhesion of the empty mass.
		var effort_kn: Variant = RailVehicleTypeData.PRICING.tractive_effort_for(veh_type)
		if effort_kn != null:
			dynamics.tractive_effort_n += float(effort_kn) * 1000.0
		elif not power_known:
			dynamics.has_unspecified_motor = true
	if is_finite(slowest):
		dynamics.max_speed_mps = slowest
	return dynamics

## Acceleration available from traction at the given speed, before any braking.
func traction_acceleration(speed_mps: float) -> float:
	if not has_motor or mass_kg <= 0.0:
		return 0.0
	var force: float = INF
	if tractive_effort_n > 0.0:
		force = tractive_effort_n
	if power_w > 0.0:
		force = minf(force, power_w / maxf(absf(speed_mps), MIN_POWER_SPEED_MPS))
	if not is_finite(force):
		return FALLBACK_ACCELERATION if has_unspecified_motor else 0.0
	return minf(force / mass_kg, MAX_TRACTION_ACCELERATION)

## Distance needed to stop from the given speed.
static func stopping_distance(speed_mps: float, deceleration: float = SERVICE_DECELERATION) -> float:
	return speed_mps * speed_mps / (2.0 * deceleration)

## Highest speed from which the train can still stop within the given distance.
static func approach_speed(distance: float, deceleration: float = SERVICE_DECELERATION) -> float:
	return sqrt(2.0 * deceleration * maxf(distance, 0.0))

static func _positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0
