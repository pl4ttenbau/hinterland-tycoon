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

## Step the controller at 60 Hz directly, independent of machine frame rate.
func simulate(movement: TrainMovement, seconds: float, move: bool = true) -> void:
	for _step: int in range(roundi(seconds * 60.0)):
		movement.update_speed(1.0 / 60.0)
		if move:
			movement.move_forwards(1.0 / 60.0)

## A bare vehicle with only the data that movement reads.
func make_vehicle(train: Train3D, veh_type: VehicleTypeData) -> Vehicle3D:
	var vehicle := Vehicle3D.new()
	vehicle.train3d = train
	vehicle.vehicle_obj = VehicleData.new()
	vehicle.vehicle_obj.veh_type = veh_type
	return vehicle

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
	self.simulate(movement, 1.0)
	self.check(movement.m_passed_since_start > start_distance, "A depot train accelerates and advances")
	self.simulate(movement, 60.0)
	var rollout_end: float = start_distance + train.length_in_m() + 10.0
	self.check(is_equal_approx(movement.m_passed_since_start, rollout_end), "The rollout brakes to a stop at the full consist length plus 10 metres")
	self.check(is_zero_approx(movement.speed_mps) and is_zero_approx(movement.speed.target), "After the rollout the train stands with no target speed")
	for vehicle: Vehicle3D in train.vehicles:
		self.check(is_equal_approx(vehicle.global_position.y, 0.262066), "Rollout keeps each vehicle at rail-head height")
	self.simulate(movement, 1.0)
	self.check(is_equal_approx(movement.m_passed_since_start, rollout_end), "The train remains parked at the rollout limit")
	movement.speed.target = 1.0
	self.simulate(movement, 1.0)
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
	var dialog_panel: Control = dialog.get_node("Panel")
	await get_tree().process_frame
	await get_tree().process_frame
	check(dialog_panel.size.x >= 700.0 and dialog_panel.size.y >= 500.0
		and (dialog_panel.position + dialog_panel.size * 0.5).is_equal_approx(dialog.size * 0.5),
		"The expanded coupling panel remains centered")
	check(dialog.dialog_key == "TrainCouplingDialog" and UiState.movement_blocked, "Coupling is a modal game dialog")
	dialog._consist.list.item_selected.emit(1)
	dialog._preview_split(true)
	check(train.count() == 2 and dialog._confirm_bar.confirm.text == "Confirm split", "Preview leaves the original joint connected")
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
	check(dialog._confirm_bar.summary.text.begins_with("Front") and train.count() == 1 and parked.count() == 1,
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
		and is_equal_approx(two_sided._consist.list.get_global_rect().end.y,
			two_sided._rear.button.get_global_rect().end.y),
		"Both coupling actions are visible and the columns align at the bottom")
	var stale: TrainCoupling.Connection = TrainCoupling.nearby(train, false)
	two_sided._preview_join(false)
	check(not two_sided._confirm_bar.confirm.disabled, "The rear joint can be confirmed while the route fits")
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
	check(two_sided._confirm_bar.confirm.disabled and two_sided._confirm_bar.summary.text.contains(route_error),
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

## Exercise early wiring, the physical speed model and controller lifetime.
func _test_movement() -> bool:
	## Use the production scene so its instantiation notification supplies the dependency.
	var train: Train3D = load(Train3D.EMPTY_SCENE_PATH).instantiate()
	## The controller must already exist before factory configuration or tree insertion.
	var movement: TrainMovement = train.movement
	self.check(movement != null and movement.train == train, "Instantiation wires the explicit train reference")
	self.check(movement.process_physics_priority < train.process_physics_priority, "Movement runs before model effects sample displacement")
	self.check(not train.is_inside_tree() and not movement.is_started, "Wiring does not insert or start the train")
	## 10 kN on 20 t gives 0.5 m/s² until 1000 kW limits the force, far above 10 m/s.
	var engine_type := VehicleTypeData.new()
	engine_type.has_motor = true
	engine_type.max_speed_kmh = 36
	engine_type.mass_tonnes = 20.0
	engine_type.tractive_effort_kn = 10.0
	engine_type.motor_power_kw = 1000.0
	engine_type.length_metres = 10.0
	train.add_vehicle(self.make_vehicle(train, engine_type), true)
	var dynamics: TrainDynamics = movement.get_dynamics()
	self.check(is_equal_approx(dynamics.max_speed_mps, 10.0), "Maximum speed comes from the catalog in km/h")
	self.check(is_equal_approx(dynamics.traction_acceleration(0.0), 0.5), "Tractive effort limits starting acceleration")
	self.check(is_equal_approx(TrainDynamics.stopping_distance(5.0), 25.0), "Service braking from 5 m/s needs 25 m")
	self.check(is_equal_approx(TrainDynamics.approach_speed(25.0), 5.0), "Approach speed is the inverse of stopping distance")
	movement.speed.target = 0.5
	movement.update_speed(1.0)
	self.check(is_zero_approx(movement.speed_mps), "Target requests before startup do not move the train")
	self.check(movement.start(), "Start can be requested before scene insertion")
	self.get_tree().root.add_child(train)
	self.check(is_equal_approx(movement.speed.target, 0.5), "Start preserves the selected target")
	self.simulate(movement, 4.0, false)
	self.check(is_equal_approx(movement.speed_mps, 2.0) and is_equal_approx(movement.speed.current, 0.2),
		"Four seconds at 0.5 m/s² reach 2 m/s, shown as 20 % of maximum speed")
	self.simulate(movement, 10.0, false)
	self.check(is_equal_approx(movement.speed_mps, 5.0), "Acceleration ends at the selected target")
	## The brake control decelerates faster and keeps the driver's traction request.
	movement.speed.brake_applied = true
	self.simulate(movement, 2.0, false)
	self.check(is_equal_approx(movement.speed_mps, 3.0), "The brake control decelerates at 1 m/s²")
	self.check(is_equal_approx(movement.speed.target, 0.5), "Braking preserves the selected target")
	self.simulate(movement, 5.0, false)
	self.check(is_zero_approx(movement.speed_mps) and movement.is_started, "The brake holds zero without switching off movement")
	movement.speed.brake_applied = false
	self.simulate(movement, 2.0, false)
	self.check(is_equal_approx(movement.speed_mps, 1.0), "Releasing the brake resumes towards the selected target")
	movement.speed.target = 0.05
	self.simulate(movement, 0.5, false)
	self.check(is_equal_approx(movement.speed_mps, 0.75), "A lower target uses service braking at 0.5 m/s²")
	## 50 kW gives only 5 kN at 10 m/s.
	engine_type.motor_power_kw = 50.0
	self.check(is_equal_approx(movement.get_dynamics().traction_acceleration(10.0), 0.25), "Power limits acceleration at higher speed")
	engine_type.motor_power_kw = 1000.0
	var wagon_type := VehicleTypeData.new()
	wagon_type.max_speed_kmh = 18
	wagon_type.mass_tonnes = 20.0
	var consist: Array[VehicleTypeData] = [engine_type, wagon_type]
	var wagons_only: Array[VehicleTypeData] = [wagon_type]
	self.check(is_equal_approx(TrainDynamics.of_types(consist).max_speed_mps, 5.0), "The slowest vehicle sets the consist's maximum speed")
	self.check(is_equal_approx(TrainDynamics.of_types(consist).traction_acceleration(0.0), 0.25), "Wagon mass reduces acceleration")
	self.check(is_zero_approx(TrainDynamics.of_types(wagons_only).traction_acceleration(0.0)), "An unpowered consist cannot accelerate")
	## Stop zeroes the speed; later target edits do nothing until the next start.
	movement.stop()
	self.check(is_zero_approx(movement.speed_mps) and is_zero_approx(movement.speed.current), "Stop zeroes the speed")
	movement.speed.target = 0.75
	movement.update_speed(1.0)
	self.check(is_zero_approx(movement.speed_mps) and not movement.is_started, "Target changes while stopped do not move the train")
	movement.start()
	movement.speed.current = 0.5
	self.check(is_equal_approx(movement.speed_mps, 5.0), "External corrections of the speed fraction set the physical speed")
	## Parenthood is for lifetime only; the explicit train reference identifies the controlled train.
	var controller_host := Node.new()
	self.add_child(controller_host)
	movement.reparent(controller_host)
	self.check(movement.train == train and movement.get_parent() != train, "Movement keeps its explicit train after reparenting")
	movement.derail()
	self.check(movement.derailed and not movement.is_started and is_zero_approx(movement.speed_mps), "Derailment stops the train")
	self.check(not movement.start() and is_zero_approx(movement.speed.current), "Derailed movement cannot restart")
	controller_host.free()
	train.free()
	return true
