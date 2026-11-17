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
	if await self._test_spawn() != true:
		self.check(false, "Production train spawn test did not finish")
	if self._test_movement() != true:
		self.check(false, "Movement test did not finish")
	print("Train movement tests: %d passed, %d failures" % [self.passed, self.failures])
	self.get_tree().quit.call_deferred(0 if self.failures == 0 else 1)

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
	var player := PlayerAvatar.new()
	GlobalState.player = player
	var price: int = composition.purchase_price()
	player.company.cash = price - 1
	check(action.spawn_train(composition).contains("Insufficient funds") and placer.trains.is_empty()
		and player.company.cash == price - 1, "Unaffordable train order leaves cash and the depot unchanged")
	player.company.cash = CompanyData.STARTING_CASH
	check(action.spawn_train(composition).is_empty(), "The full consist can be purchased")
	check(price == 111_200 and player.company.cash == CompanyData.STARTING_CASH - price,
		"Train purchase charges both the locomotive and wagon")
	GlobalState.player = null
	player.free()
	if placer.trains.is_empty():
		return false
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
	if await _test_coupling(placer, train, track) != true:
		self.check(false, "Coupling test did not finish")
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

func _test_coupling(placer: VehiclePlacer, train: Train3D, track: RailTrackData) -> bool:
	var engine: Vehicle3D = train.locomotive
	var wagon: Vehicle3D = train.vehicles.back()
	var movement: TrainMovement = train.movement
	movement.stop()
	movement.m_passed_since_start = 45.0
	movement.update_segment_progress()
	movement.place_vehicles()
	var wagon_pose: Transform3D = wagon.global_transform
	var player: PlayerAvatar = load("res://scenes/subscenes/player.tscn").instantiate()
	add_child(player)
	var menu_scene: PackedScene = load("res://scenes/ui/radial_menu/radial_action_menu.tscn")
	var menu: RadialActionMenu = menu_scene.instantiate()
	add_child(menu)
	var actions := ActionHandler.new()
	add_child(actions)
	check(not menu.available_actions().any(func(item: Dictionary) -> bool: return item.id == "Coupling") \
		and not actions._on_action_triggered("Coupling"), "Coupling cannot open on foot even with a train in the world")
	check(player.control.enter_train(train), "Board the selected train before opening the dialog")
	check(menu.available_actions().any(func(item: Dictionary) -> bool: return item.id == "Coupling"),
		"The radial menu offers Coupling in the cab")
	menu.free()
	check(actions._on_action_triggered("Coupling"), "The radial action opens the coupling dialog")
	var dialog := UiState.current_diag as TrainCouplingDialog
	if dialog == null:
		return false
	var dialog_panel: Control = dialog.get_node("OuterPanel")
	await get_tree().process_frame
	await get_tree().process_frame
	check(dialog_panel.size.x >= 700.0 and dialog_panel.size.y >= 500.0
		and (dialog_panel.position + dialog_panel.size * 0.5).is_equal_approx(dialog.size * 0.5),
		"The expanded coupling panel remains centered")
	check(dialog.dialog_key == "TrainCouplingDialog" and UiState.movement_blocked, "Coupling is a modal game dialog")
	dialog._select_vehicle(1)
	dialog._preview_split(true)
	check(train.count() == 2 and dialog._confirm.text == "Confirm split", "Preview leaves the original joint connected")
	dialog._commit()
	var parked: Train3D = wagon.train3d
	check(parked != train and parked.locomotive == null and parked.train_obj.vehicles == [wagon.vehicle_obj],
		"Uncoupling creates a registered wagon-only consist")
	check(parked in placer.trains and parked in GlobalState.trains and parked.num != train.num,
		"The parked wagon has its own train identity")
	check(player.control.current_train() == train and train.locomotive == engine
		and wagon.global_transform.is_equal_approx(wagon_pose) and dialog._selected == wagon,
		"Splitting keeps the cab, the wagon's pose and the dialog selection")
	check(dialog._front.pair.text.contains(engine.vehicle_obj.veh_type.display_name)
		and not dialog._rear.button.visible, "The detached wagon sees the engine in front")
	dialog._preview_join(true)
	check(dialog._summary.text.begins_with("Front") and train.count() == 1 and parked.count() == 1,
		"The dialog previews the front joint of the selected wagon")
	dialog._commit()
	check(wagon.train3d == train and player.control.current_train() == train and dialog._selected == wagon,
		"Coupling onto the occupied cab retains it and keeps the wagon selected")
	check(TrainCoupling.split(train, engine, wagon).is_empty(), "The rejoined consist can split again")
	parked = wagon.train3d
	dialog.close_all()
	remove_child(player)
	player.free()
	var rear: TrainCoupling.Connection = TrainCoupling.nearby(train, false)
	check(rear != null and rear.other == parked and rear.facing_end == wagon,
		"The engine sees the detached wagon behind it")
	if rear == null:
		return false
	movement.speed.current = 0.01
	check(not TrainCoupling.join(train, rear).is_empty() and train.count() == 1, "Moving trains cannot couple")
	movement.speed.current = 0.0
	var source_stock: GoodsInventory = parked.get_inventory()
	var target_stock: GoodsInventory = train.get_inventory()
	source_stock.storage.change_amount(&"coal", 2.0)
	source_stock.delivered_cargo[&"coal"] = 1.0
	target_stock.storage.change_amount(&"coal", 149.0)
	check(not TrainCoupling.join(train, rear).is_empty() and wagon.train3d == parked,
		"A join that cannot fit the combined stock leaves both consists intact")
	target_stock.storage.change_amount(&"coal", -149.0)
	check(TrainCoupling.join(train, rear).is_empty() and train.vehicles == [engine, wagon]
		and wagon.global_transform.is_equal_approx(wagon_pose), "Rear coupling restores the consist without moving either vehicle")
	check(is_equal_approx(target_stock.storage.get_amount(&"coal"), 2.0)
		and is_equal_approx(target_stock.delivered_cargo[&"coal"], 1.0), "Coupling retains stock and delivery metadata")
	check(parked not in placer.trains and parked not in GlobalState.trains and parked.is_queued_for_deletion(),
		"The absorbed consist leaves both train registries immediately")

	var start_pos := VehicleStartPos.of(track.num, 0, movement.direction)
	var facing: Train3D = placer.spawn_train("mpsb_12", start_pos)
	facing.movement.is_reversed = true
	facing.movement.m_passed_since_start = movement.m_passed_since_start \
		+ (engine.vehicle_obj.veh_type.length_metres + 0.3) * (-1.0 if movement.is_reversed else 1.0)
	facing.movement.update_segment_progress()
	facing.movement.place_vehicles()
	var other_engine: Vehicle3D = facing.locomotive
	var facing_basis: Basis = other_engine.global_basis
	var front: TrainCoupling.Connection = TrainCoupling.nearby(train, true)
	check(front != null and front.other == facing and front.reverse_order, "Front-to-front coupling detects the facing end")
	check(TrainCoupling.join(train, front).is_empty() and train.vehicles == [other_engine, engine, wagon]
		and train.locomotive == engine and other_engine.global_basis.is_equal_approx(facing_basis),
		"Front coupling preserves cab ownership and the other engine's orientation")
	check(TrainCoupling.split(train, other_engine, engine).is_empty()
		and other_engine.train3d.locomotive == other_engine and train.vehicles == [engine, wagon],
		"A front split retains the original cab and creates a second powered consist")
	var rear_distance: float = movement.get_vehicle_distance(wagon)
	var rear_train: Train3D = placer.spawn_train("mpsb_12", start_pos)
	rear_train.movement.m_passed_since_start = rear_distance - (wagon.vehicle_obj.veh_type.length_metres \
		+ rear_train.locomotive.vehicle_obj.veh_type.length_metres) * 0.5 - 0.4
	rear_train.movement.update_segment_progress()
	rear_train.movement.place_vehicles()
	check(TrainCoupling.nearby(train, true) != null and TrainCoupling.nearby(train, false) != null,
		"The same consist can show candidates at both ends")
	await get_tree().process_frame
	var two_sided := TrainCouplingDialog.create(engine)
	get_tree().root.add_child(two_sided)
	await get_tree().process_frame
	await get_tree().process_frame
	check(two_sided._front.button.visible and two_sided._rear.button.visible
		and is_equal_approx(two_sided._current_list.get_global_rect().end.y,
			two_sided._rear.button.get_global_rect().end.y),
		"Both coupling actions are visible and the columns align at the bottom")
	var stale: TrainCoupling.Connection = TrainCoupling.nearby(train, false)
	two_sided._preview_join(false)
	check(not two_sided._confirm.disabled, "The rear joint can be confirmed while the route fits")
	var spacing: float = (wagon.vehicle_obj.veh_type.length_metres \
		+ rear_train.locomotive.vehicle_obj.veh_type.length_metres) * 0.5
	## Both ends still face each other, but closing the joint needs a centre beyond the buffer.
	movement.m_passed_since_start = wagon.offset_to_first + spacing - 0.15
	movement.update_segment_progress()
	movement.place_vehicles()
	rear_train.movement.m_passed_since_start = 0.0
	rear_train.movement.update_segment_progress()
	rear_train.movement.place_vehicles()
	two_sided._refresh()
	var route_error: String = "The joined consist cannot fit on the current rail route."
	check(two_sided._rear.button.visible and two_sided._rear.button.disabled \
		and two_sided._rear.pair.text.contains(route_error), "The nearby list explains why the join will not fit")
	check(two_sided._confirm.disabled and two_sided._summary.text.contains(route_error),
		"An open preview disables confirmation when the route no longer fits")
	check(TrainCoupling.join(train, stale) == route_error and train.count() == 2 and rear_train.count() == 1,
		"Confirmation checks the same route fit before changing either consist")
	two_sided.close_all()
	rear_train.movement.m_passed_since_start = spacing + 2.0
	rear_train.movement.place_vehicles()
	check(TrainCoupling.nearby(train, false) == null and not TrainCoupling.join(train, stale).is_empty(),
		"A preview cannot couple a vehicle that has moved out of range")
	actions.free()
	await get_tree().process_frame
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
