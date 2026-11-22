## Physical description of one consist, collected from its vehicles' catalog data, plus the forces and
## rates that follow from it. The formulas themselves live in RailPhysics; this class only decides which
## numbers of which vehicles feed them (masses, motors, brakes, kind of train).
##
## Built fresh on demand (see TrainMovement.get_dynamics), so coupling and splitting need no bookkeeping.
## Units: metres, seconds, kilograms, newtons and watts, as in RailPhysics.
class_name TrainDynamics extends RefCounted

## Used when no vehicle in the consist states a maximum speed (former fixed top speed).
const LEGACY_MAX_SPEED_MPS: float = 6.0
## Mass assumed for a vehicle whose catalog entry has no mass at all.
const DEFAULT_VEHICLE_MASS_TONNES: float = 10.0
## A powered vehicle with neither power, tractive effort nor mass in the catalog still moves off gently:
## it gets enough force for this acceleration on its own consist. Keeps half-catalogued vehicles drivable.
const FALLBACK_ACCELERATION: float = 0.3
## Brake percentage assumed for a vehicle whose braked mass is not catalogued. 85 % gives a full brake of
## 0.85 m/s² and service braking of ~0.5 m/s², matching the rates the game used before brakes were
## modelled, so uncatalogued stock keeps its familiar stopping behaviour. Unbraked vehicles (0 t) count 0.
const DEFAULT_BRAKE_PERCENTAGE: float = 85.0
## Floor for the planning deceleration. A consist of only unbraked wagons would otherwise plan with zero
## deceleration, i.e. infinite stopping distances, and refuse to move at all. Running resistance alone
## gives roughly this much, so it is what such a train really has left.
const MIN_PLANNING_DECELERATION: float = 0.05

var max_speed_mps: float = LEGACY_MAX_SPEED_MPS
## Current mass of the whole consist: service mass of every vehicle. Cargo is not added yet.
var mass_kg: float = 0.0
## Rated engine power summed over all motors.
var power_w: float = 0.0
## Starting tractive effort summed over all motors: authored, else estimated from adhesive mass.
var tractive_effort_n: float = 0.0
var has_motor: bool = false
## At least one motor lacks power, tractive effort and mass, so FALLBACK_ACCELERATION applies.
var has_unspecified_motor: bool = false
## Sum of braked masses, with DEFAULT_BRAKE_PERCENTAGE standing in where the catalog is silent.
var braked_mass_kg: float = 0.0
## Rotating-mass factor ξ: a locomotive running light spins proportionally far more mass than a train.
var mass_factor: float = RailPhysics.MASS_FACTOR_TRAIN
## Strahl air coefficient: freight consists are gappier and draggier than passenger ones.
var strahl_k: float = RailPhysics.STRAHL_K_MIXED_PASSENGER

static func of_vehicles(vehicles: Array[RailVehicle3D]) -> TrainDynamics:
	var types: Array[VehicleTypeData] = []
	for vehicle: RailVehicle3D in vehicles:
		if is_instance_valid(vehicle) and vehicle.vehicle_obj != null and vehicle.vehicle_obj.veh_type != null:
			types.append(vehicle.vehicle_obj.veh_type)
	return of_types(types)

static func of_types(types: Array[VehicleTypeData]) -> TrainDynamics:
	var dynamics := TrainDynamics.new()
	var slowest: float = INF
	var all_powered: bool = not types.is_empty()
	## Counted over unpowered vehicles only: those decide what the train looks like to the wind.
	var freight_wagons: int = 0
	var passenger_wagons: int = 0
	for veh_type: VehicleTypeData in types:
		if _positive(veh_type.max_speed_kmh):
			slowest = minf(slowest, RailPhysics.kmh_to_mps(float(veh_type.max_speed_kmh)))
		## Vehicles run in working order: fuel, water and sand count, so use the service mass.
		var running_tonnes: Variant = veh_type.get_service_mass_tonnes()
		var vehicle_kg: float = (float(running_tonnes) if running_tonnes != null else DEFAULT_VEHICLE_MASS_TONNES) * 1000.0
		dynamics.mass_kg += vehicle_kg
		## Braked mass: authored (0 = unbraked), else the default share of this vehicle's mass.
		var braked: Variant = veh_type.braked_mass_tonnes
		if (braked is int or braked is float) and is_finite(float(braked)) and braked >= 0:
			dynamics.braked_mass_kg += float(braked) * 1000.0
		else:
			dynamics.braked_mass_kg += vehicle_kg * DEFAULT_BRAKE_PERCENTAGE / 100.0
		if not veh_type.has_motor:
			all_powered = false
			if veh_type.capacity != null and veh_type.capacity.goods_cat != BaseGoodsType.ResourceCategory.PASSENGER:
				freight_wagons += 1
			elif veh_type.capacity != null:
				passenger_wagons += 1
			continue
		dynamics.has_motor = true
		var power_known: bool = _positive(veh_type.motor_power_kw)
		if power_known:
			dynamics.power_w += float(veh_type.motor_power_kw) * 1000.0
		## Shares the pricing estimate: authored effort, otherwise adhesion of the adhesive service mass.
		## The adhesion limit is not applied on top of authored values: published starting efforts already
		## are what the wheels can transmit, often at a better μ than the game's cautious estimate.
		var effort_kn: Variant = RailVehicleTypeData.PRICING.tractive_effort_for(veh_type)
		if effort_kn != null:
			dynamics.tractive_effort_n += float(effort_kn) * 1000.0
		elif not power_known:
			dynamics.has_unspecified_motor = true
	if is_finite(slowest):
		dynamics.max_speed_mps = slowest
	if all_powered:
		dynamics.mass_factor = RailPhysics.MASS_FACTOR_LOCOMOTIVE
	if freight_wagons > passenger_wagons:
		dynamics.strahl_k = RailPhysics.STRAHL_K_MIXED_FREIGHT
	return dynamics

#region Forces
## Tractive effort at the rail for the given speed and throttle (0..1): the starting effort up to the
## corner speed, then the power hyperbola η·P/v. See RailPhysics.tractive_effort for the curve.
func traction_force(speed_mps: float, throttle: float = 1.0) -> float:
	if not self.has_motor or self.mass_kg <= 0.0:
		return 0.0
	var force: float = RailPhysics.tractive_effort(speed_mps, self.power_w, self.tractive_effort_n, 0.0, throttle)
	if force <= 0.0 and self.has_unspecified_motor:
		## No data at all: enough force for the fallback rate, scaled by the throttle like a real motor.
		force = FALLBACK_ACCELERATION * self.mass_factor * self.mass_kg * clampf(throttle, 0.0, 1.0)
	return force

## Running resistance (bearings, rolling, air) of the whole consist after Strahl. Grows with speed.
## Uses the one coefficient for the whole train, locomotive included; good enough at narrow-gauge speeds.
func resistance_force(speed_mps: float) -> float:
	return RailPhysics.strahl_resistance(self.mass_kg, speed_mps, self.strahl_k)

## Net acceleration at full power on level track: what the driver gets when opening the throttle.
## Never negative here; above the balancing speed the train simply stops gaining (callers handle coasting).
func traction_acceleration(speed_mps: float) -> float:
	if self.mass_kg <= 0.0:
		return 0.0
	return maxf(0.0, RailPhysics.acceleration(self.mass_kg, speed_mps, self.traction_force(speed_mps),
		self.resistance_force(speed_mps), 0.0, 0.0, self.mass_factor))
#endregion

#region Brakes
## Braked mass in percent of train mass (Bremshundertstel λ).
func brake_percentage() -> float:
	return RailPhysics.brake_percentage(self.braked_mass_kg, self.mass_kg)

## Brake force of a full application: the brake control, or overspeed towards a stopping point.
func full_brake_force() -> float:
	return RailPhysics.full_brake_force(self.mass_kg, self.brake_percentage(), self.mass_factor)

## Brake force of an ordinary service stop: lowering the target speed.
func service_brake_force() -> float:
	return RailPhysics.service_brake_force(self.mass_kg, self.brake_percentage(), self.mass_factor)

## Deceleration that stop planning (signals, buffers, rollout) assumes: service brakes only, on the
## level. Running resistance is left out on purpose, so the real train always stops a little early
## rather than late.
func planning_deceleration() -> float:
	var brakes_only: float = RailPhysics.full_brake_deceleration(self.brake_percentage()) * RailPhysics.SERVICE_BRAKE_SHARE
	return maxf(brakes_only, MIN_PLANNING_DECELERATION)

## Distance needed to stop from the given speed with service braking.
func stopping_distance(speed_mps: float) -> float:
	return RailPhysics.stopping_distance(speed_mps, self.planning_deceleration())

## Highest speed from which the consist can still stop within the given distance.
func approach_speed(distance: float) -> float:
	return RailPhysics.approach_speed(distance, self.planning_deceleration())
#endregion

static func _positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0
