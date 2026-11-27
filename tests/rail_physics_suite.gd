extends RefCounted
## Pure arithmetic checks for RailPhysics; worked examples are computed by hand in the comments.

var failures: int = 0
var tree: SceneTree

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func near(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	for test: Callable in [test_traction, test_resistance_and_grade, test_braking, test_motion, test_planning]:
		check(await test.call() == true, "%s completed without runtime errors" % test.get_method())
	print("Rail physics tests: %d failures" % failures)
	return 1 if failures > 0 else 0

func test_traction() -> bool:
	## 34 t on driven axles at μ 0.25: 34 000 · 9.81 · 0.25 = 83 385 N.
	check(near(RailPhysics.adhesion_limit(34000.0), 83385.0), "Adhesion limit is μ · m · g")
	## 400 kW at 80 % and 10 m/s: 32 kN; below 1 m/s the curve is flat at 320 kN.
	check(near(RailPhysics.power_limit(400000.0, 10.0), 32000.0), "Power limit is η · P / v")
	check(near(RailPhysics.power_limit(400000.0, 0.0), 320000.0), "Power limit stays finite at standstill")
	## Authored 100 kN, adhesion 83 kN: the wheels slip first.
	check(near(RailPhysics.tractive_effort(0.0, 400000.0, 100000.0, 34000.0), 83385.0), "Adhesion caps an over-strong motor")
	check(near(RailPhysics.tractive_effort(10.0, 400000.0, 100000.0, 34000.0), 32000.0), "Power takes over at speed")
	check(near(RailPhysics.tractive_effort(10.0, 400000.0, 100000.0, 0.0, 0.5), 16000.0), "Throttle scales the effort")
	check(is_zero_approx(RailPhysics.tractive_effort(5.0, 0.0)), "Nothing driving means no effort")
	## 320 kW at the rail meets 100 kN at 3.2 m/s.
	check(near(RailPhysics.corner_speed(400000.0, 100000.0), 3.2), "Corner speed joins both limits")
	return true

func test_resistance_and_grade() -> bool:
	## 40 km/h + 12 wind = 52 → 2.5 + 0.033 · 5.2² = 3.39232 ‰.
	var at_40: float = RailPhysics.kmh_to_mps(40.0)
	check(near(RailPhysics.strahl_resistance_permille(at_40), 3.39232), "Strahl ‰ matches the worked example")
	check(near(RailPhysics.strahl_resistance(57000.0, at_40), 3.39232 / 1000.0 * 57000.0 * 9.81, 0.01), "Strahl force scales with weight")
	check(RailPhysics.strahl_resistance_permille(at_40) == RailPhysics.strahl_resistance_permille(-at_40), "Resistance ignores direction")
	check(RailPhysics.strahl_resistance_permille(at_40, RailPhysics.STRAHL_K_EMPTY_FREIGHT)
		> RailPhysics.strahl_resistance_permille(at_40, RailPhysics.STRAHL_K_COACHES), "Empty freight resists more than coaches")
	check(near(RailPhysics.davis_resistance(-2.0, 100.0, 10.0, 1.0), 124.0), "Davis is A + B·v + C·v²")
	## 10 ‰ on 100 t: 100 000 · 9.81 · 0.01 = 9 810 N.
	check(near(RailPhysics.grade_force(100000.0, 10.0), 9810.0), "Grade force is m · g · ‰ / 1000")
	check(RailPhysics.grade_force(100000.0, -10.0) < 0.0, "Downhill pushes the train on")
	return true

func test_braking() -> bool:
	check(near(RailPhysics.brake_percentage(40000.0, 50000.0), 80.0), "Brake percentage is braked over train mass")
	check(is_zero_approx(RailPhysics.brake_percentage(1.0, 0.0)), "No train, no brake percentage")
	check(near(RailPhysics.full_brake_deceleration(80.0), 0.8), "Full braking scales linearly with λ")
	## On the level without resistance, the brake force reproduces the nominal deceleration.
	var force: float = RailPhysics.full_brake_force(50000.0, 80.0)
	check(near(RailPhysics.deceleration(50000.0, 10.0, force), 0.8), "Full brake force gives the nominal rate")
	check(near(RailPhysics.service_brake_force(50000.0, 80.0), force * RailPhysics.SERVICE_BRAKE_SHARE), "Service braking uses a share")
	return true

func test_motion() -> bool:
	## 10 kN net on 10 t with ξ 1.0: 1 m/s².
	check(near(RailPhysics.acceleration(10000.0, 5.0, 12000.0, 2000.0, 0.0, 0.0, 1.0), 1.0), "Net force over mass")
	check(near(RailPhysics.acceleration(10000.0, 5.0, 10000.0, 0.0, 0.0, 0.0, 1.25), 0.8), "Mass factor slows acceleration")
	## Standing: a 1 kN push against 2 kN of brake does nothing, in either direction.
	check(is_zero_approx(RailPhysics.acceleration(10000.0, 0.0, 1000.0, 0.0, 0.0, 2000.0, 1.0)), "Brakes hold a standing train")
	check(is_zero_approx(RailPhysics.acceleration(10000.0, 0.0, 0.0, 0.0, 1000.0, 2000.0, 1.0)), "Brakes hold it on a slope")
	## Standing: 3 kN downhill against 2 kN of brake leaves 1 kN rolling it back.
	check(near(RailPhysics.acceleration(10000.0, 0.0, 0.0, 0.0, 3000.0, 2000.0, 1.0), -0.1), "A weak brake loses on a steep slope")
	## Downhill grade larger than the brakes: the train speeds up while braking.
	check(RailPhysics.deceleration(10000.0, 5.0, 1000.0, 0.0, RailPhysics.grade_force(10000.0, -20.0)) < 0.0, "Runaway is reported as negative deceleration")
	## Constant 100 kN traction against v-proportional resistance balances where 100 000 = 10 000 · v.
	var traction: Callable = func(_v: float) -> float: return 100000.0
	var resistance: Callable = func(v: float) -> float: return 10000.0 * v
	check(near(RailPhysics.balancing_speed(traction, resistance, 0.0, 50.0), 10.0), "Balancing speed is where forces cancel")
	check(near(RailPhysics.balancing_speed(traction, resistance, 0.0, 5.0), 5.0), "The catalog limit wins when lower")
	check(is_zero_approx(RailPhysics.balancing_speed(traction, resistance, 200000.0, 50.0)), "Too steep a bank means no movement")
	## Jerk limit: 0.4 m/s³ for 0.5 s moves acceleration by 0.2, never past the target.
	check(near(RailPhysics.limit_jerk(0.0, 1.0, 0.5), 0.2), "Jerk limit caps the change of acceleration")
	check(near(RailPhysics.limit_jerk(0.9, 1.0, 0.5), 1.0), "Jerk limit does not overshoot")
	check(near(RailPhysics.limit_jerk(1.0, 0.0, 0.5), 0.8), "Jerk limit applies when easing off")
	return true

func test_planning() -> bool:
	check(near(RailPhysics.stopping_distance(5.0, 0.5), 25.0), "Stopping distance is v² / 2a")
	check(near(RailPhysics.stopping_distance(5.0, 0.5, 2.0), 35.0), "Brake response adds v · t")
	check(RailPhysics.stopping_distance(5.0, 0.0) == INF, "Without deceleration the train never stops")
	check(near(RailPhysics.approach_speed(25.0, 0.5), 5.0), "Approach speed inverts stopping distance")
	check(near(RailPhysics.approach_speed(35.0, 0.5, 2.0), 5.0), "Approach speed respects brake response")
	return true
