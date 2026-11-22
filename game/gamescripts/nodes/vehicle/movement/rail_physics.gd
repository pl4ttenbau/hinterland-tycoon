## Stateless longitudinal rail dynamics ("Fahrdynamik"): the forces acting on a train along the track,
## and how they turn into acceleration and deceleration.
##
## This file only does arithmetic. It knows nothing about the catalog, vehicles or nodes; callers such as
## TrainDynamics collect the numbers (masses, power, tractive effort, brake data) and pass them in.
## That keeps the formulas testable in isolation and lets road or other vehicles reuse them later.
##
## Units, everywhere unless a parameter name says otherwise:
##   distance m, time s, speed m/s, mass kg, force N, power W, acceleration m/s², jerk m/s³.
## Railway literature mixes in km/h, tonnes, kN and ‰ (per mille, "Promille"); conversions happen at
## the edges of each function and are named in the parameter (e.g. `grade_permille`).
##
## The equation of motion for the whole train, treated as one rigid mass:
##
##     ξ · m · a = F_traction(v) − F_resistance(v) − F_grade − F_brake
##
## where
##   m       is the current train mass (service mass of every vehicle plus its load),
##   ξ (xi)  is the rotating-mass factor ("Massenfaktor"): wheelsets, gears, motor armatures and
##           cardan shafts must be spun up as well as moved, which behaves like extra mass,
##   F_traction is limited by adhesion at low speed and by power at higher speed (see tractive_effort),
##   F_resistance is running resistance: bearings, rolling, flange friction and air (see strahl_resistance),
##   F_grade is the downhill component of gravity, negative when descending (see grade_force),
##   F_brake is the braking force the driver or the protection system applies.
##
## Sources consulted for the formulas and typical values (2026-11-22):
##   - TU Dresden, Kache: Formelsammlung Fahrdynamik (Strahl, Massenfaktor, Bremshundertstel)
##   - EPFL traction lecture notes (rotating-mass factor ranges)
##   - Wikipedia "Rail vehicle resistance" (Davis equation)
## Several coefficients below were recalled from that literature rather than copied out of it;
## those are marked "verify" and should be checked against a Formelsammlung before tuning around them.
class_name RailPhysics extends RefCounted

#region Constants
## Standard gravity. Railways use 9.81 throughout; the extra digits would be false precision.
const GRAVITY: float = 9.81
## Multiply m/s by this to get km/h, divide km/h by it to get m/s.
const KMH_PER_MPS: float = 3.6

## Rotating-mass factors ξ (dimensionless, always ≥ 1).
## A whole adhesion train is dominated by wagons with light wheelsets, so its factor stays small.
const MASS_FACTOR_TRAIN: float = 1.06
## Wagons alone: just the wheelsets turn.
const MASS_FACTOR_WAGON: float = 1.03
## A locomotive running light: motors, gears and heavy driving wheels weigh in. EPFL gives 1.15–1.30;
## the middle of that range is a reasonable default for diesel and electric locomotives.
const MASS_FACTOR_LOCOMOTIVE: float = 1.2

## Adhesion coefficient μ between driven wheel and rail when starting. Dry clean rail allows ~0.33,
## wet or leafy rail drops to 0.1 and below. 0.25 matches RailVehiclePricing.estimated_adhesion and is a
## fair "average weather, sand available" value for older diesel and steam locomotives.
const DEFAULT_ADHESION: float = 0.25

## Share of engine power that reaches the rail. Losses are in the transmission (hydraulic converter,
## generator/motors, gearbox) and auxiliaries (cooling fans, compressor, lighting).
## Diesel-hydraulic: ~0.75–0.80 at its best point and less elsewhere; diesel-electric ~0.80–0.85;
## electric locomotives ~0.85–0.90. 0.8 is a fair default for the game's mostly diesel fleet. Verify.
const DEFAULT_TRANSMISSION_EFFICIENCY: float = 0.8
## Power-limited tractive effort is P / v, which grows without bound as v approaches 0. Below this speed
## the power curve is held flat; in practice adhesion or the authored starting effort caps it far earlier.
const MIN_POWER_SPEED_MPS: float = 1.0

## Strahl's formula for the running resistance of a wagon train ("Wagenzugwiderstand"):
##
##     w [‰] = c + k · ((v_kmh + Δv) / 10)²        and        R = w / 1000 · m · g
##
## w is the specific resistance in per mille of the train's weight force (N per kN). `c` covers speed-
## independent bearing and rolling losses, the squared term the air, including an allowance Δv for
## headwind. The original Strahl formula uses c = 2.5 ‰, appropriate for plain (friction) bearings as on
## the game's historic stock; roller-bearing stock is nearer 1.4–2.0 ‰. Verify against Kache.
const STRAHL_BASE_PERMILLE: float = 2.5
## Headwind allowance Δv in km/h added to the train speed before squaring. 12 km/h for passenger trains;
## some sources use 15 km/h for freight.
const STRAHL_WIND_KMH: float = 12.0
## Strahl's air coefficient k by kind of train. Larger means a less streamlined, gappier consist.
## Values for four-axle coaches and empty freight are recalled, mixed freight (0.05) is confirmed. Verify.
const STRAHL_K_COACHES: float = 0.025
const STRAHL_K_MIXED_PASSENGER: float = 0.033
const STRAHL_K_MIXED_FREIGHT: float = 0.05
## Empty open wagons catch the air inside them, so they resist about twice as much as loaded ones.
const STRAHL_K_EMPTY_FREIGHT: float = 0.1

## Deceleration a train achieves in a full brake application per unit of brake percentage, i.e. at
## λ = 100 % it stops at this rate. Real brake-percentage tables are non-linear and depend on brake
## type (P/G) and speed; this linear rule is a game simplification that lands in the documented range of
## 0.9–1.1 m/s² for well-braked passenger trains. Not a railway standard.
const FULL_BRAKE_DECELERATION_AT_100_PERCENT: float = 1.0
## Ordinary service stops use part of the available brake force, leaving reserve for emergencies.
## 0.6 of full gives ~0.6 m/s² for a well-braked passenger train and ~0.3–0.4 for a freight train with
## λ ≈ 55–65 %, both within typical service values.
const SERVICE_BRAKE_SHARE: float = 0.6
## A comfortable limit for how fast acceleration may change. Passengers start to notice above ~0.5 m/s³;
## real drivers notch up over a few seconds, which is a large part of why trains feel slow to start.
const DEFAULT_MAX_JERK: float = 0.4
## Speeds at or below this count as standing for the static-friction case in acceleration().
const STANDSTILL_MPS: float = 0.001
#endregion

#region Unit helpers
static func kmh_to_mps(speed_kmh: float) -> float:
	return speed_kmh / KMH_PER_MPS

static func mps_to_kmh(speed_mps: float) -> float:
	return speed_mps * KMH_PER_MPS

## Weight force of a mass: the reference all ‰ quantities (resistance, grade) are taken against.
static func weight_force(mass_kg: float) -> float:
	return mass_kg * GRAVITY
#endregion

#region Traction
## Most force the driven wheels can transmit before slipping: μ times the weight resting on driven axles.
## Pass the *adhesive* mass, i.e. the service mass ("Dienstmasse") carried by motored axles only. For a
## locomotive with all axles driven that is its whole service mass; for a railcar with one powered bogie
## it is roughly half. Empty mass is wrong here: fuel, water and sand all press the wheels onto the rail.
static func adhesion_limit(adhesive_mass_kg: float, adhesion: float = DEFAULT_ADHESION) -> float:
	return maxf(adhesive_mass_kg, 0.0) * GRAVITY * maxf(adhesion, 0.0)

## Force that the engine's power can sustain at the given speed: F = η · P / v.
## Power is force times speed, so at constant power the force halves whenever the speed doubles.
## Below MIN_POWER_SPEED_MPS the curve is held flat so that standing starts stay finite.
static func power_limit(power_w: float, speed_mps: float,
		efficiency: float = DEFAULT_TRANSMISSION_EFFICIENCY) -> float:
	if power_w <= 0.0:
		return 0.0
	return efficiency * power_w / maxf(absf(speed_mps), MIN_POWER_SPEED_MPS)

## Available tractive effort at the rail for the given speed: the familiar hyperbolic curve.
##
##   force │‾‾‾‾‾‾‾‾\           starting effort (authored, or the adhesion limit) holds at low speed,
##         │         `-.        then the power hyperbola η·P/v takes over above the "corner" speed
##         │            `--..___
##         └──────────────────────── speed
##
## `starting_effort_n` is the authored maximum tractive effort ("Anfahrzugkraft"). Pass 0 when unknown
## and give `adhesive_mass_kg` instead; the adhesion limit then stands in for it. When both are given,
## the smaller wins: a locomotive cannot pull harder than its wheels grip, however strong its motors.
## With neither, the result is purely power-limited.
## `throttle` (0..1) scales the result. A driver notching up, or a jerk limiter, works through it.
static func tractive_effort(speed_mps: float, power_w: float, starting_effort_n: float = 0.0,
		adhesive_mass_kg: float = 0.0, throttle: float = 1.0,
		efficiency: float = DEFAULT_TRANSMISSION_EFFICIENCY, adhesion: float = DEFAULT_ADHESION) -> float:
	var force: float = INF
	if starting_effort_n > 0.0:
		force = starting_effort_n
	if adhesive_mass_kg > 0.0:
		force = minf(force, adhesion_limit(adhesive_mass_kg, adhesion))
	if power_w > 0.0:
		force = minf(force, power_limit(power_w, speed_mps, efficiency))
	if not is_finite(force):
		## Nothing limits it, which means nothing drives it either.
		return 0.0
	return force * clampf(throttle, 0.0, 1.0)

## Speed above which power rather than starting effort limits the force: where the flat part of the
## curve meets the hyperbola. Handy for UI ("full effort up to 14 km/h") and for sanity-checking data.
static func corner_speed(power_w: float, starting_effort_n: float,
		efficiency: float = DEFAULT_TRANSMISSION_EFFICIENCY) -> float:
	if power_w <= 0.0 or starting_effort_n <= 0.0:
		return 0.0
	return efficiency * power_w / starting_effort_n
#endregion

#region Resistance
## Specific running resistance after Strahl, in ‰ of the weight force (equivalently N per kN).
## Exposed separately because railway tables and balance discussions are all written in ‰.
## Speed is taken as a magnitude: resistance always opposes motion, the caller applies the sign.
static func strahl_resistance_permille(speed_mps: float, k: float = STRAHL_K_MIXED_PASSENGER,
		base_permille: float = STRAHL_BASE_PERMILLE, wind_kmh: float = STRAHL_WIND_KMH) -> float:
	var relative_kmh: float = mps_to_kmh(absf(speed_mps)) + wind_kmh
	return base_permille + k * pow(relative_kmh / 10.0, 2.0)

## Running resistance force of a wagon train of the given current mass (empty plus load).
## Worked example: 57 t at 40 km/h, k = 0.033, c = 2.5 ‰
##   → w = 2.5 + 0.033 · (52 / 10)² ≈ 3.39 ‰ → R ≈ 0.00339 · 57 000 kg · 9.81 ≈ 1.9 kN.
## That is small next to ~80 kN of starting effort: on narrow-gauge speeds resistance mostly matters for
## coasting and near top speed, not for the start.
## Note: the formula is fitted at standstill-free running. Starting resistance ("Anfahrwiderstand") of
## plain-bearing stock can briefly be several times higher; it is deliberately ignored here.
static func strahl_resistance(mass_kg: float, speed_mps: float, k: float = STRAHL_K_MIXED_PASSENGER,
		base_permille: float = STRAHL_BASE_PERMILLE, wind_kmh: float = STRAHL_WIND_KMH) -> float:
	return strahl_resistance_permille(speed_mps, k, base_permille, wind_kmh) / 1000.0 * weight_force(mass_kg)

## Davis-form running resistance R = A + B·v + C·v², with coefficients in SI (N, N·s/m, N·s²/m²).
## Use this for locomotives or self-propelled railcars when per-vehicle coefficients are known; Strahl
## has no good locomotive variant (German practice uses separate formulas such as Sauthoff's).
## A: rolling and bearing losses, proportional to weight;  B: flange and track losses growing with speed;
## C: aerodynamic drag, ½·ρ·c_d·A_front, independent of mass.
static func davis_resistance(speed_mps: float, a_n: float, b_n_s_per_m: float, c_n_s2_per_m2: float) -> float:
	var v: float = absf(speed_mps)
	return a_n + b_n_s_per_m * v + c_n_s2_per_m2 * v * v
#endregion

#region Grade
## Gravity component along the track. Railways state gradients in ‰: metres of climb per kilometre,
## positive uphill. For gradients this small (a steep main line is 25 ‰, a rack railway is not covered),
## sin(angle) ≈ tan(angle) = grade / 1000, so the force is simply m · g · grade / 1000.
## Positive result: pulls the train back (uphill). Negative: pushes it on (downhill).
## Rule of thumb that falls out of this: each 1 ‰ of climb costs as much as 1 ‰ of running resistance,
## so a 10 ‰ bank is roughly three times the whole Strahl resistance at 40 km/h.
static func grade_force(mass_kg: float, grade_permille: float) -> float:
	return weight_force(mass_kg) * grade_permille / 1000.0
#endregion

#region Braking
## Brake percentage λ ("Bremshundertstel"): braked mass in percent of train mass.
## Each vehicle has a braked mass ("Bremsgewicht") stamped on it, found by brake tests; an unbraked
## vehicle contributes 0. A train needs a minimum λ for its line speed, which is why unbraked or
## lightly braked wagons force a lower speed limit.
static func brake_percentage(braked_mass_kg: float, train_mass_kg: float) -> float:
	if train_mass_kg <= 0.0:
		return 0.0
	return 100.0 * maxf(braked_mass_kg, 0.0) / train_mass_kg

## Deceleration of a full brake application from brakes alone, linear in λ (game rule, see constant).
## Resistance and grade still add on top; see deceleration().
static func full_brake_deceleration(brake_percentage_value: float) -> float:
	return maxf(brake_percentage_value, 0.0) / 100.0 * FULL_BRAKE_DECELERATION_AT_100_PERCENT

## Brake force that a full application produces on a train of the given mass and brake percentage.
## Expressed as a force so it can be fed through the same equation of motion as everything else, and
## so that the mass factor and grade are handled once, in deceleration().
## The mass factor is folded in so that on the level, without resistance, the train decelerates at
## exactly full_brake_deceleration(λ): brake tests measure stopping, rotating masses included.
static func full_brake_force(train_mass_kg: float, brake_percentage_value: float,
		mass_factor: float = MASS_FACTOR_TRAIN) -> float:
	return mass_factor * train_mass_kg * full_brake_deceleration(brake_percentage_value)

## Brake force for an ordinary service stop: a fixed share of the full force (see SERVICE_BRAKE_SHARE).
static func service_brake_force(train_mass_kg: float, brake_percentage_value: float,
		mass_factor: float = MASS_FACTOR_TRAIN) -> float:
	return SERVICE_BRAKE_SHARE * full_brake_force(train_mass_kg, brake_percentage_value, mass_factor)
#endregion

#region Equation of motion
## Net acceleration from all longitudinal forces, positive forwards:
##     a = (F_traction − F_brake − F_resistance − F_grade) / (ξ · m)
## All forces are passed as magnitudes except `grade_n`, which keeps the sign from grade_force().
## Resistance and brake only ever oppose motion; when the train stands, they can at most cancel the
## other forces (a braked train on a slope does not start rolling backwards from its own brakes).
## Pass `speed_mps` so that standstill can be detected; anything at or below `STANDSTILL_MPS` counts.
static func acceleration(mass_kg: float, speed_mps: float, traction_n: float, resistance_n: float = 0.0,
		grade_n: float = 0.0, brake_n: float = 0.0, mass_factor: float = MASS_FACTOR_TRAIN) -> float:
	if mass_kg <= 0.0:
		return 0.0
	var effective_mass: float = mass_factor * mass_kg
	## The forces that act regardless of motion: what the engine pushes, what gravity pulls.
	var driving: float = traction_n - grade_n
	## The forces that only resist motion: brakes and running resistance.
	var opposing: float = maxf(brake_n, 0.0) + maxf(resistance_n, 0.0)
	if absf(speed_mps) <= STANDSTILL_MPS:
		## Static friction case: opposing forces hold the train until the driving force exceeds them,
		## then only the excess accelerates it. In either direction.
		if absf(driving) <= opposing:
			return 0.0
		return (driving - signf(driving) * opposing) / effective_mass
	## Moving: opposing forces act against the direction of travel.
	return (driving - signf(speed_mps) * opposing) / effective_mass

## Convenience for the braking side: how fast the train sheds speed (positive number) while moving
## forwards with no traction. Brakes, running resistance and an uphill grade all help; a downhill grade
## works against the brakes, and on a steep enough descent the result can turn negative (runaway).
static func deceleration(mass_kg: float, speed_mps: float, brake_n: float, resistance_n: float = 0.0,
		grade_n: float = 0.0, mass_factor: float = MASS_FACTOR_TRAIN) -> float:
	return -acceleration(mass_kg, maxf(absf(speed_mps), STANDSTILL_MPS * 2.0), 0.0, resistance_n,
		grade_n, brake_n, mass_factor)

## Speed at which traction just balances resistance and grade ("Beharrungsgeschwindigkeit"): the train's
## true top speed for that load and gradient, possibly below the catalog limit for heavy trains or banks.
## Found by bisection because the forces are only known as callables; both must be ≥ 0 and the net force
## must fall with speed, which holds for every realistic traction and resistance curve.
## `traction_at` and `resistance_at` take a speed in m/s and return a force in N.
## Returns `max_speed_mps` when the train can still accelerate there, and 0 when it cannot move at all.
static func balancing_speed(traction_at: Callable, resistance_at: Callable, grade_n: float,
		max_speed_mps: float, iterations: int = 40) -> float:
	var net_at: Callable = func(v: float) -> float:
		return float(traction_at.call(v)) - float(resistance_at.call(v)) - grade_n
	if net_at.call(max_speed_mps) >= 0.0:
		return max_speed_mps
	if net_at.call(0.0) <= 0.0:
		return 0.0
	var low: float = 0.0
	var high: float = max_speed_mps
	for _i: int in range(iterations):
		var mid: float = 0.5 * (low + high)
		if net_at.call(mid) > 0.0:
			low = mid
		else:
			high = mid
	return low
#endregion

#region Driver feel
## Move `current` towards `target` by at most `max_rate · delta_seconds`. Applied to acceleration it is
## a jerk limit; applied to a 0..1 throttle it is a notching speed. Either removes the instant leap from
## standstill to full acceleration that makes a train look like a toy.
## Symmetric on purpose: easing off power is as gradual as applying it. Emergency braking should bypass
## this and set its value directly.
static func approach_rate_limited(current: float, target: float, max_rate: float, delta_seconds: float) -> float:
	var max_step: float = maxf(max_rate, 0.0) * maxf(delta_seconds, 0.0)
	return current + clampf(target - current, -max_step, max_step)

## Jerk-limited acceleration step, named for readability at call sites.
static func limit_jerk(current_acceleration: float, desired_acceleration: float, delta_seconds: float,
		max_jerk: float = DEFAULT_MAX_JERK) -> float:
	return approach_rate_limited(current_acceleration, desired_acceleration, max_jerk, delta_seconds)
#endregion

#region Planning
## Distance needed to stop from `speed_mps` at a constant deceleration: v² / (2·a).
## Assumes the deceleration is already established. A real brake needs a few seconds to build pressure
## along the train ("Bremsansprechzeit"); add speed · response_time if the planner should account for it.
static func stopping_distance(speed_mps: float, deceleration_mps2: float, response_seconds: float = 0.0) -> float:
	if deceleration_mps2 <= 0.0:
		return INF
	var v: float = absf(speed_mps)
	return v * maxf(response_seconds, 0.0) + v * v / (2.0 * deceleration_mps2)

## Inverse of stopping_distance: the highest speed from which the train still stops within `distance`.
## Solves d = v·t + v²/(2a) for v, so the brake response time is respected as well.
static func approach_speed(distance: float, deceleration_mps2: float, response_seconds: float = 0.0) -> float:
	if deceleration_mps2 <= 0.0:
		return 0.0
	var d: float = maxf(distance, 0.0)
	var t: float = maxf(response_seconds, 0.0)
	## v²/(2a) + t·v − d = 0  →  v = a · (−t + √(t² + 2d/a))
	return deceleration_mps2 * (-t + sqrt(t * t + 2.0 * d / deceleration_mps2))
#endregion
