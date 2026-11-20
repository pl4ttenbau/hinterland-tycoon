## Run the construction workflow with real world services, rail scenes, and terrain emitters.
## godot --headless --path . res://tests/rail_construction_test.tscn -- --no-mcp
extends Node

const Grass = preload("res://game/gamescripts/nodes/world/terrain_grass.gd")
const Wheat = preload("res://game/gamescripts/nodes/world/terrain_wheat.gd")

var checks: int = 0
var failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(1))
	check(await _test_construction() == true, "Rail construction test completed")
	print("Rail construction: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_construction() -> bool:
	if GameTypes.ensure_initialized() != OK:
		return false
	await get_tree().process_frame
	var services: WorldServicesCoordinator = load("res://scenes/subscenes/world_services.tscn").instantiate()
	add_child(services)
	if services.initialize() != OK:
		return false
	services.world_timer.stop()
	services.passenger_timer.stop()
	UiState.in_main_menu = false
	var player := PlayerAvatar.new()
	player.walking_body = BasicFpsPlayer.new()
	player.add_child(player.walking_body)
	GlobalState.player = player

	# Use a real terrain region and both vegetation layers. The path will cross
	# the X=16 emitter boundary, so adjacent tiles must both receive clearance.
	var world := WorldMapScene.new()
	var terrain := Terrain3D.new()
	world.terrain = terrain
	world.add_child(terrain)
	services.map_spawner.terrain_container = world
	services.map_spawner.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(8, 4, 8)
	add_child(camera)
	terrain.set_camera(camera)
	terrain.data.add_region_blankp(Vector3.ZERO)
	var grass := Grass.new()
	var wheat := Wheat.new()
	for layer: Grass in [grass, wheat]:
		layer.grass_areas = GrassAreaDefinition.new()
		terrain.add_child(layer)
		layer._update_tiles(Vector2i.ZERO)

	# Start at node zero so entering this junction uses reverse travel. The
	# non-chord authored tangent proves the preview preserves authored geometry.
	var approach := RailTrackData.new()
	approach.num = 25
	approach.infr_type_key = "1000_MM"
	var junction := RailNodeData.of(0, Vector3(12, 0.2, 10), approach)
	junction.handle_out = Vector3(-3, 0, 0.3)
	var endpoint := RailNodeForkData.new()
	endpoint.railNode = junction
	junction.fork = endpoint
	approach.add_node(junction, false)
	approach.add_node(RailNodeData.of(1, Vector3(2, 0.2, 10), approach), false)
	approach.build_curve()
	var approach_curve: Curve3D = approach.curve
	services.rails.track_storage.add(approach)
	var fork: NewRailForkData = services.forks.get_fork_at_pos(junction.position)
	var fork_view: RailFork3D = services.forks.spawn_single_fork(fork)
	fork.refresh_setting()
	var approach_segment := VehiclePathSegment.of_rail(approach.num, Enums.PathDirection.TRACK_NODES_DECREASE)
	var active_path := ActiveRailVehiclePath.of_segment(null, approach_segment)
	add_child(active_path)

	var builder: NewRailBuilder = services.rail_builder
	_begin_build(fork)
	var first_click := Vector3(22, 0, 10)
	var second_click := Vector3(31, 0, 17)
	builder._on_terrain_click(first_click)
	var preview := builder.get_node_or_null("RailConstructionPreview") as RailTrack3D
	if preview == null:
		return false
	var bedding: PathMesh3D = preview.get_bed_mesh()
	var tint := bedding.material_override as StandardMaterial3D
	check(tint != null and tint.albedo_color.g > tint.albedo_color.r, "Draft ballast has a green material")
	check(bedding.collision_mode == PathMesh3D.COLLISION_MODE_NONE, "Draft ballast has no collision")
	var junction_handle: Vector3 = preview.curve.get_point_out(0)
	builder._on_terrain_click(second_click)
	check(preview.curve.point_count == 3 and preview.curve.get_point_out(1) != Vector3.ZERO,
		"The second click smooths the former endpoint into an interior bend")
	check(preview.curve.get_point_position(0) == junction.position
		and preview.curve.get_point_out(0).is_equal_approx(junction_handle)
		and junction_handle.normalized().is_equal_approx(-junction.handle_out.normalized()),
		"Preview stays snapped and tangent to the authored approach")
	check(services.rails.track_storage.get_all().size() == 1 and fork.connected_tracks == [approach.num]
		and player.company.cash == CompanyData.STARTING_CASH and not GlobalState.outer_tracks.has(preview),
		"Planning leaves the registry, fork, and company balance untouched")
	check(grass._rail_clearance.get_cell(Vector2i.ZERO) == null and wheat._rail_clearance.get_cell(Vector2i.ZERO) == null,
		"Planning leaves grass and wheat coverage untouched")

	# Enter opens a review of exactly the geometry on screen. Back retains every
	# point, and clicks arriving while the modal is open cannot change the quote.
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	get_viewport().push_input(enter)
	var dialog := UiState.current_diag as RailConstructionDialog
	check(dialog != null, "Enter opens the rail confirmation")
	if dialog == null:
		return false
	var accepted_curve: Curve3D = preview.curve
	check(UiState.movement_blocked and player.walking_body.process_mode == Node.PROCESS_MODE_DISABLED
		and dialog.quote.gauge_mm == 1000
		and is_equal_approx(dialog.quote.length_metres, accepted_curve.get_baked_length())
		and dialog.quote.price == 2 * CompanyData.TRACK_SEGMENT_COST,
		"Review quotes the smoothed length, inherited gauge, and price of both spans")
	check(dialog.get_node("%LengthValue").text == "%.1f m" % dialog.quote.length_metres
		and dialog.get_node("%GaugeValue").text == "1000 mm"
		and dialog.get_node("%PriceValue").text == CompanyData.format_cash(dialog.quote.price),
		"The quote is visible in the review")
	builder._on_terrain_click(Vector3(40, 0, 23))
	dialog.get_node("%CancelButton").pressed.emit()
	await get_tree().process_frame
	check(UiState.current_diag == null and not UiState.movement_blocked
		and player.walking_body.process_mode == Node.PROCESS_MODE_INHERIT and preview.curve == accepted_curve,
		"Back restores editing with the original curve")

	# Change the cash after review to verify that acceptance rechecks funds.
	# A rejected acceptance keeps the draft and never stamps a vegetation mask.
	builder.review_plan()
	dialog = UiState.current_diag as RailConstructionDialog
	if dialog == null:
		return false
	player.company.cash = dialog.quote.price - 1
	dialog.get_node("%OkButton").pressed.emit()
	check(UiState.current_diag == dialog and dialog.get_node("%Status").visible
		and services.rails.track_storage.get_all().size() == 1 and player.company.spending == 0
		and grass._rail_clearance.get_cell(Vector2i.ZERO) == null,
		"An unaffordable confirmation leaves cash, track, and coverage unchanged")
	player.company.cash = dialog.quote.price
	dialog.get_node("%OkButton").pressed.emit()
	dialog.get_node("%OkButton").pressed.emit()
	check(player.company.cash == 0 and player.company.spending == 2 * CompanyData.TRACK_SEGMENT_COST,
		"Accepting charges once for the full section")
	check(not is_instance_valid(preview) and UiState.ui_mode == Enums.UiMode.WALKING,
		"Acceptance replaces the draft and exits build mode")

	# The approach was already planned before construction. Its next lookahead
	# can now enter the entire accepted section using the exact preview curve.
	var track: RailTrackData = RailTrackData.get_by_num(26)
	if track == null:
		return false
	var view: RailTrack3D = services.rails.track_storage.get_container_by_num(track.num)
	check(view != null and view.curve == accepted_curve and track.curve == accepted_curve
		and view.get_bed_mesh().collision_mode == PathMesh3D.COLLISION_MODE_TRIMESH,
		"The completed rail uses the accepted curve and solid ballast")
	active_path.ensure_lookahead(0.0)
	check(active_path.segments.size() == 2 and active_path.segments.back().track_num == track.num
		and active_path.segments.back().end_node == track.get_end_node(),
		"An existing approach route can find the full accepted section")
	check(VehiclePathSegmentBuilder.get_next_track_num_from_node(track.nodes[0]) == approach.num
		and services.rails.fork_storage.get_by_track(track.num) == track.nodes[0].fork,
		"The registered fork routes trains back to the approach")
	check(approach.curve == approach_curve and junction.handle_out == approach_curve.get_point_out(0),
		"Construction preserves the existing approach curve")
	active_path.free()

	# Test live emitter materials and CPU masks on both sides of the tile seam.
	# White pixels outside the track footprint retain the local vegetation.
	for layer: Grass in [grass, wheat]:
		var left: Image = layer._rail_clearance.get_cell(Vector2i.ZERO)
		var right: Image = layer._rail_clearance.get_cell(Vector2i(1, 0))
		check(left != null and right != null and left.get_pixel(31, 20).r == 0.0
			and right.get_pixel(0, 20).r == 0.0 and left.get_pixel(0, 0).r == 1.0,
			"Rail clears %s across the emitter seam and preserves nearby coverage" % layer.get_vegetation_layer())
		var material: ShaderMaterial = layer._tiles[Vector2i.ZERO].process_material
		check(material.get_shader_parameter("rail_clearance_enabled") == true,
			"Already active %s emitters receive the new mask" % layer.get_vegetation_layer())
		# Emitter recycling must remove the old tile's mask.
		layer._update_tiles(Vector2i(5, 5))
		check(layer._tiles[Vector2i(5, 5)].process_material == layer._process_material,
			"Recycled %s emitters use the coverage at their new location" % layer.get_vegetation_layer())
	await get_tree().process_frame
	check(UiState.current_diag == null and not UiState.movement_blocked, "Accept closes the modal and releases input")

	# A second accepted branch must keep the live switch selection and allocate
	# an unused track ID. An abandoned plan consumes neither money nor an ID.
	_begin_build(fork)
	builder._on_terrain_click(Vector3(24, 0, 5))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape)
	check(builder.get_node_or_null("RailConstructionPreview") == null
		and services.rails.track_storage._max_num == track.num and player.company.cash == 0,
		"Escape discards the plan without allocating an ID or spending money")
	_begin_build(fork)
	player.company.cash = CompanyData.TRACK_SEGMENT_COST
	builder._on_terrain_click(Vector3(24, 0, 5))
	builder.review_plan()
	dialog = UiState.current_diag as RailConstructionDialog
	if dialog == null:
		return false
	var setting: CurrentForkSetting = fork.setting.current
	dialog.get_node("%OkButton").pressed.emit()
	var second: RailTrackData = RailTrackData.get_by_num(27)
	check(second != null and fork.setting.current == setting and setting.connected == track.num
		and fork_view.fork_mesh.visible and player.company.cash == 0,
		"Adding a second branch preserves the live setting and exposes a switch")
	if second == null:
		return false
	fork.switch()
	check(VehiclePathSegmentBuilder.get_next_track_num_from_node(junction) == second.num,
		"Throwing the switch routes onto the second accepted branch")

	# The same height tolerance as the map baker should preserve grass below a
	# bridge span. This curve is well away from either of the new rail sections.
	var elevated := Curve3D.new()
	elevated.add_point(Vector3(65, 8, 65))
	elevated.add_point(Vector3(75, 8, 65))
	world.clear_rail_vegetation(elevated, 2.0)
	check(grass._rail_clearance.get_cell(Vector2i(4, 4)) == null
		and wheat._rail_clearance.get_cell(Vector2i(4, 4)) == null,
		"Elevated rail keeps the vegetation below it")

	# The fixture owns its services and resources. Break the node/track and
	# setting/fork references before freeing the test world.
	for built: RailTrackData in [track, second]:
		GlobalState.outer_tracks.erase(services.rails.track_storage.get_container_by_num(built.num))
		GlobalState.forks.erase(built.nodes[0].fork)
		built.nodes[0].fork = null
		built.forks.clear()
		built.nodes.clear()
	junction.fork = null
	approach.nodes.clear()
	fork.setting.parent = null
	GlobalState.player = null
	GlobalState.world_container = null
	player.free()
	services.free()
	camera.free()
	return true


func _begin_build(fork: NewRailForkData) -> void:
	UiState.build_infr_mode = UiModeBuildInfr.from_fork(fork)
	UiState.ui_mode = Enums.UiMode.BUILD_INFR
	SignalBus.ui_mode_switched.emit(Enums.UiMode.BUILD_INFR)
