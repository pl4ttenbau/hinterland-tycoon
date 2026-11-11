extends Node

## Count failures explicitly so headless runs return a useful exit code.
var failures: int = 0
## Count successful checks to make the exercised behaviour visible in the log.
var passed: int = 0

func _ready() -> void:
	self._run.call_deferred()

## Continue after failures so one run reports all independent regressions.
func check(condition: bool, message: String) -> void:
	if condition:
		self.passed += 1
	else:
		self.failures += 1
		push_error(message)

## Stepping a paused tween makes time-based assertions independent of machine frame rate.
func advance_ramp(movement: TrainMovement, seconds: float) -> void:
	if movement._speed_tween == null:
		self.check(false, "Expected an active speed tween")
		return
	movement._speed_tween.pause()
	movement._speed_tween.custom_step(seconds)

## Detect aborted tests as well as failed checks, and always finish with a process exit code.
func _run() -> void:
	if self._test_train_data() != true:
		self.check(false, "Train data setter test did not finish")
	if self._test_spawn() != true:
		self.check(false, "Production train spawn test did not finish")
	if self._test_movement() != true:
		self.check(false, "Movement test did not finish")
	print("Train movement tests: %d passed, %d failures" % [self.passed, self.failures])
	self.get_tree().quit(0 if self.failures == 0 else 1)

## Assign through the public property so a recursive setter cannot hide behind bare scene fixtures.
func _test_train_data() -> bool:
	## The factory assigns the locomotive and registers it as the train's first vehicle.
	var locomotive := VehicleData.new()
	## Construction must return normally rather than recursively assigning the same property.
	var data: TrainData = TrainData.of(locomotive)
	self.check(data.locomotive == locomotive, "TrainData factory stores its locomotive without recursion")
	self.check(data.vehicles.size() == 1 and data.vehicles[0] == locomotive, "TrainData registers the initial locomotive once")
	## Capture both events to preserve the existing observable property behaviour.
	var notifications: Array[String] = []
	data.locomotive_changed.connect(func(_vehicle: VehicleData): notifications.append("locomotive"))
	data.vehicles_changed.connect(func(_vehicles: Array[VehicleData]): notifications.append("vehicles"))
	## Later assignments must use the same safe setter and keep emitting both events.
	var replacement := VehicleData.new()
	data.locomotive = replacement
	self.check(data.locomotive == replacement, "Later locomotive assignments also return normally")
	self.check(data.vehicles.back() == replacement, "Locomotive assignment retains vehicle registration")
	self.check(notifications == ["locomotive", "vehicles"], "Locomotive assignment emits both change signals once")
	return true

## Use the actual catalog, train factory and model rather than bypassing spawn_locomotive().
func _test_spawn() -> bool:
	self.check(GameTypes.ensure_initialized() == OK, "Vehicle catalog initializes for the real spawn test")
	## A short fixture track supplies the network lookup used by VehicleStartPos and movement.
	var rails := RailsLoader.new()
	## Restore the existing manager after this isolated fixture is released.
	var previous_rails: RailsLoader = Managers.rails
	Managers.rails = rails
	## Keep this route unconnected so no world or fork service is needed.
	var track := RailTrackData.new()
	track.num = 55
	track.infr_type_key = "600_MM"
	track.add_node(RailNodeData.of(0, Vector3.ZERO, track), false)
	track.add_node(RailNodeData.of(1, Vector3(0.0, 0.0, -100.0), track), false)
	track.build_curve()
	rails.track_storage.add(track)
	var previous_vehicles: VehiclePlacer = Managers.vehicles
	var placer := VehiclePlacer.new()
	self.add_child(placer)
	Managers.vehicles = placer
	var depot := RailDepotData.new()
	depot.num = 55
	depot.track_num = 55
	depot.track_pos = "END"
	GlobalState.rail_depots.append(depot)
	var action := SpawnAction.new()
	action.last_clicked_depot_num = depot.num
	var composition := TrainVehicleListDto.new()
	composition.append(TrainVehicleDto.of(0, "mpsb_12"))
	composition.append(TrainVehicleDto.of(1, "mpsb_wismar_wagon"))
	action.spawn_train(composition)
	var train: Train3D = placer.trains[0]
	var movement: TrainMovement = train.movement
	self.check(train.train_obj != null and train.train_obj.locomotive == train.locomotive.vehicle_obj, "Production spawn links train data to the locomotive")
	self.check(train.train_obj.vehicles.size() == 2 and train.vehicles.size() == 2, "Production spawn includes the locomotive and wagon")
	self.check(movement.train == train and movement.active_path != null, "Production spawn wires movement and initializes the route")
	for vehicle: Vehicle3D in train.vehicles:
		self.check(is_equal_approx(vehicle.global_position.y, 0.262066), "Depot spawn places the whole train at rail-head height")
	var start_distance: float = movement.m_passed_since_start
	self.advance_ramp(movement, 1.0)
	movement.move_forwards(0.5)
	self.check(movement.m_passed_since_start > start_distance, "A depot train accelerates and advances")
	self.advance_ramp(movement, 20.0)
	movement.move_forwards(10.0)
	var rollout_end: float = start_distance + train.length_in_m() + 10.0
	self.check(is_equal_approx(movement.m_passed_since_start, rollout_end), "The last rollout step stops at the full consist length plus 10 metres")
	for vehicle: Vehicle3D in train.vehicles:
		self.check(is_equal_approx(vehicle.global_position.y, 0.262066), "Rollout keeps each vehicle at rail-head height")
	movement.move_forwards(1.0)
	self.check(is_equal_approx(movement.m_passed_since_start, rollout_end), "The train remains parked at the rollout limit")
	movement.speed.target = 1.0
	self.advance_ramp(movement, 1.0)
	movement.move_forwards(0.5)
	self.check(movement.m_passed_since_start > rollout_end, "A driver can pull away after the depot rollout")
	GlobalState.rail_depots.erase(depot)
	GlobalState.trains.erase(train)
	action.free()
	placer.free()
	Managers.vehicles = previous_vehicles
	for node: RailNodeData in track.nodes:
		node.parent_track = null
	Managers.rails = previous_rails
	rails.free()
	return true

## Exercise early wiring, speed interpolation, interrupted ramps and controller lifetime.
func _test_movement() -> bool:
	## Use the production scene so its instantiation notification supplies the dependency.
	var train: Train3D = load(Train3D.EMPTY_SCENE_PATH).instantiate()
	## The controller must already exist before factory configuration or tree insertion.
	var movement: TrainMovement = train.movement
	self.check(movement != null and movement.train == train, "Instantiation wires the explicit train reference")
	self.check(movement.process_physics_priority < train.process_physics_priority, "Movement runs before model effects sample displacement")
	self.check(not train.is_inside_tree() and not movement.is_started, "Wiring does not insert or start the train")
	movement.speed.target = 0.5
	self.check(movement._speed_tween == null, "Target requests before startup create no tween")
	self.check(movement.start(), "Start can be requested before scene insertion")
	self.check(movement._speed_tween == null, "Early start waits for the scene tree before creating a tween")
	self.get_tree().root.add_child(train)
	self.check(movement._speed_tween != null, "Entering the tree creates the pending speed tween")
	self.check(is_equal_approx(movement.speed.target, 0.5), "Start preserves the selected target")
	self.advance_ramp(movement, 5.0)
	self.check(is_equal_approx(movement.speed.current, 0.125), "Half of the ten-second ramp gives quadratic speed 0.125")
	## A new target must kill the old ramp and begin at the actual current speed.
	var replaced_tween: Tween = movement._speed_tween
	movement.speed.target = 0.25
	self.check(not replaced_tween.is_valid(), "Changing target kills the previous tween")
	self.check(is_equal_approx(movement.speed.current, 0.125), "Changing target does not jump speed")
	self.advance_ramp(movement, 1.25)
	self.check(is_equal_approx(movement.speed.current, 0.15625), "Retargeted ramp starts from actual speed")
	self.advance_ramp(movement, 1.25)
	self.check(is_equal_approx(movement.speed.current, 0.25) and movement._speed_tween == null, "Completed ramp reaches the target and releases its tween")
	## Braking halves the duration and retains the driver's traction request.
	movement.speed.brake_applied = true
	self.advance_ramp(movement, 1.25)
	self.check(is_equal_approx(movement.speed.current, 0.1875), "Brake uses the faster quadratic ramp")
	self.check(is_equal_approx(movement.speed.target, 0.25), "Braking preserves the selected target")
	self.advance_ramp(movement, 1.25)
	self.check(is_zero_approx(movement.speed.current) and movement.is_started, "Service brake holds zero without switching off movement")
	movement.speed.brake_applied = false
	self.advance_ramp(movement, 2.5)
	self.check(is_equal_approx(movement.speed.current, 0.0625), "Releasing the brake resumes towards the selected target")
	## Stop and later target edits must not revive a killed speed tween.
	replaced_tween = movement._speed_tween
	movement.stop()
	self.check(not replaced_tween.is_valid() and is_zero_approx(movement.speed.current), "Stop kills the tween before zeroing speed")
	movement.speed.target = 0.75
	self.check(movement._speed_tween == null and not movement.is_started, "Target changes while stopped do not start a ramp")
	movement.speed.brake_applied = true
	movement.start()
	self.check(movement._speed_tween == null and is_zero_approx(movement.speed.current), "Starting with the brake applied holds zero")
	movement.speed.brake_applied = false
	self.advance_ramp(movement, 7.5)
	self.check(is_equal_approx(movement.speed.current, 0.1875), "Restart uses the saved target instead of resetting to full speed")
	## Direct corrections should replace the current ramp rather than fight it next frame.
	replaced_tween = movement._speed_tween
	movement.speed.current = 0.5
	self.check(not replaced_tween.is_valid(), "External speed corrections replace the tween")
	self.advance_ramp(movement, 2.5)
	self.check(is_equal_approx(movement.speed.current, 0.5625), "Correction retargets from the externally supplied speed")
	## Parenthood is for lifetime only; the explicit train reference identifies the controlled train.
	var controller_host := Node.new()
	self.add_child(controller_host)
	movement.reparent(controller_host)
	self.check(movement.train == train and movement.get_parent() != train, "Movement keeps its explicit train after reparenting")
	movement.start()
	self.advance_ramp(movement, 1.0)
	replaced_tween = movement._speed_tween
	movement.derail()
	self.check(not replaced_tween.is_valid() and movement.derailed, "Derailment cancels the active ramp")
	self.check(not movement.start() and is_zero_approx(movement.speed.current), "Derailed movement cannot restart")
	movement.derailed = false
	movement.start()
	replaced_tween = movement._speed_tween
	controller_host.free()
	self.check(not replaced_tween.is_valid(), "Freeing the controller cancels its tween")
	train.free()
	return true
