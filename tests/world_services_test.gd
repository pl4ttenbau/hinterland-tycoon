extends Node

const SERVICES = preload("res://scenes/subscenes/world_services.tscn")

var failures: int = 0
var local_completions: int = 0
var global_completions: int = 0

func _ready() -> void:
	self._run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		self.failures += 1
		push_error(message)

func _on_global_initialized() -> void:
	self.global_completions += 1
	self.check(GameTypes.is_initialized and Managers.are_world_services_initialized(), "Global completion publishes ready services after types")

func _on_local_initialized(coordinator: WorldServicesCoordinator) -> void:
	self.local_completions += 1
	self.check(Managers.world_services == coordinator, "Coordinator owns active services at completion")
	self.check(Managers.towns == coordinator.towns and Managers.town_buildings == coordinator.town_buildings, "Town services are registered")
	self.check(Managers.rails == coordinator.rails and Managers.forks == coordinator.forks and Managers.roads == coordinator.roads, "Infrastructure services are registered")
	self.check(Managers.stations == coordinator.stations and Managers.depots == coordinator.depots, "Stations and depots are registered")
	self.check(Managers.vehicles == coordinator.vehicles and Managers.industries == coordinator.industries and Managers.map_spawner == coordinator.map_spawner, "Remaining world services are registered")
	self.check(coordinator.town_buildings.has_res_bld_types_loaded, "Late subscribers use persistent type readiness")
	self.check(not coordinator.world_timer.is_stopped() and not coordinator.passenger_timer.is_stopped(), "Timers start after wiring")

func _run() -> void:
	self.check(self.test_service_lifecycle(), "Service lifecycle test finished")
	self.check(self.test_residence_conversion(), "Residence conversion test finished")
	self.check(self.test_all_residence_variants(), "All residence variants test finished")
	print("World services tests: %d failures" % self.failures)
	get_tree().quit(1 if self.failures > 0 else 0)

func test_service_lifecycle() -> bool:
	var map_list_loader: MapLoader = Managers.map_list_loader
	var initial_connections: int = SignalBus.map_selected.get_connections().size()
	SignalBus.services_initialized.connect(self._on_global_initialized)
	var coordinator: WorldServicesCoordinator = SERVICES.instantiate()
	# Reverse siblings before mounting: initialization must not rely on their order.
	for child: Node in coordinator.get_children():
		coordinator.move_child(child, 0)
	self.check(Managers.world_services == null and Managers.towns == null, "Construction does not publish services")
	self.add_child(coordinator)
	self.check(Managers.world_services == null, "Tree entry does not publish services")
	self.check(coordinator.world_timer.is_stopped() and coordinator.passenger_timer.is_stopped(), "Timers wait for initialization")
	self.check(coordinator.initialize() == ERR_UNCONFIGURED, "Services cannot initialize before types")
	self.check(not Managers.are_world_services_initialized(), "Failed initialization does not publish readiness")
	self.check(GameTypes.ensure_initialized() == OK, "Type catalog initializes")
	coordinator.services_initialized.connect(self._on_local_initialized.bind(coordinator))
	self.check(coordinator.initialize() == OK, "Reordered services initialize after types")
	var connection_count: int = SignalBus.map_selected.get_connections().size()
	self.check(connection_count > initial_connections, "Map listeners are connected explicitly")
	self.check(coordinator.initialize() == OK, "Repeated initialization is harmless")
	self.check(SignalBus.map_selected.get_connections().size() == connection_count, "Repeated initialization does not duplicate listeners")
	self.check(self.local_completions == 1 and self.global_completions == 1, "Completion signals fire once per coordinator")
	self.check(coordinator.rails.track_storage.track_added.is_connected(coordinator.forks._on_track_loaded), "Fork loader is wired to track storage")
	var replacement: WorldServicesCoordinator = SERVICES.instantiate()
	self.add_child(replacement)
	self.check(replacement.initialize() == ERR_ALREADY_IN_USE, "A second active session cannot replace service registrations")
	self.check(Managers.world_services == coordinator, "Rejected session preserves active services")
	self.remove_child(coordinator)
	self.check(not Managers.are_world_services_initialized() and Managers.rails == null and Managers.towns == null, "Unmounting clears session registrations")
	self.check(Managers.map_list_loader == map_list_loader, "Application services survive session cleanup")
	self.check(SignalBus.map_selected.get_connections().size() == initial_connections, "Unmounted services release global listeners before being freed")
	self.check(not coordinator.rails.track_storage.track_added.is_connected(coordinator.forks._on_track_loaded), "Unmounting releases Resource listeners")
	self.check(coordinator.world_timer.is_stopped() and coordinator.passenger_timer.is_stopped(), "Unmounting stops timers")
	coordinator.free()
	replacement.services_initialized.connect(self._on_local_initialized.bind(replacement))
	self.check(replacement.initialize() == OK, "A replacement can initialize after the previous session exits")
	self.check(self.local_completions == 2 and self.global_completions == 2, "Replacement announces its own completion")
	replacement.free()
	self.check(Managers.world_services == null and Managers.map_spawner == null, "Freeing the replacement clears its services")
	self.check(SignalBus.map_selected.get_connections().size() == initial_connections, "Replacement cleanup restores listener count")
	return true

func test_residence_conversion() -> bool:
	var previous_world: WorldMapScene = GlobalState.world_container
	var towns := TownPlacer.new()
	Managers.towns = towns
	var town := TownData.with_num(9876)
	towns.storage.add(town)
	var world := WorldMapScene.new()
	self.add_child(world)
	var houses := Node3D.new()
	houses.name = "Residences"
	houses.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(100, 7, 20))
	world.add_child(houses)
	houses.owner = world
	var editor: Node3D = load("res://assets/meshes/structures/wooden_shack/editor_wooden_shack.tscn").instantiate()
	editor.placed_town_num = town.num
	editor.transform = Transform3D(Basis(Vector3.UP, 0.8).scaled(Vector3(2, 2, 2)), Vector3(3, 2, 1))
	houses.add_child(editor)
	var expected_transform: Transform3D = editor.global_transform
	var door := Marker3D.new()
	door.name = "Door"
	door.position = Vector3(1, 0, -2)
	editor.add_child(door)
	var door_position: Vector3 = door.global_position
	var legacy := Residence3D.new()
	legacy.placed_res_bld_type = "wooden_shack"
	legacy.placed_town_num = town.num
	houses.add_child(legacy)
	var holder := TownBuildingHolder.new()
	self.add_child(holder)
	var initial_count: int = GlobalState.res_blds.size()
	holder.load_preplaced_town_buildings()
	holder.load_preplaced_town_buildings()
	self.check(holder.placed_buildings.size() == 2 and town.res_bld_containers.size() == 2, "Both editor and legacy houses register exactly once")
	self.check(GlobalState.res_blds.size() == initial_count + 2, "Repeated loading creates no duplicate simulation data")
	var runtime: Residence3D = door.get_parent() as Residence3D
	self.check(runtime != null and editor.get_parent() == null, "Editor placement is replaced with a runtime residence")
	self.check(runtime.global_transform.is_equal_approx(expected_transform), "Conversion preserves the full world transform")
	self.check(door.global_position.is_equal_approx(door_position), "Authored door and child overrides survive conversion")
	self.check(runtime.get_node_or_null("StaticBody3D") != null, "Shared model collider survives conversion")
	self.check(runtime.res_bld_obj.is_registered and runtime.res_bld_obj.town_num == town.num, "Converted house has registered runtime data and town assignment")
	self.check(runtime.num != legacy.num, "Runtime houses receive distinct IDs")
	for residence: Residence3D in holder.placed_buildings:
		GlobalState.res_blds.erase(residence.res_bld_obj)
		GlobalState.res_bld_containers.erase(residence)
	GlobalState.towns.erase(town)
	town.res_bld_containers.clear()
	world.free()
	editor.free()
	holder.free()
	towns.free()
	Managers.towns = null
	GlobalState.world_container = previous_world
	return true

func test_all_residence_variants() -> bool:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(ResidentialBldTypeLoader.CATALOG_PATH))
	var editor_script: Script = load("res://game/gamescripts/nodes/structures/editor_residence_3d.gd")
	var container := Node3D.new()
	self.add_child(container)
	for entry: Dictionary in catalog:
		var runtime_path: String = entry["scene_path"]
		var editor_path: String = runtime_path.get_base_dir().path_join("editor_" + runtime_path.get_file())
		var packed: PackedScene = load(editor_path)
		self.check(packed != null, "Editor scene loads: %s" % entry["key"])
		if packed == null:
			continue
		var placement: Node3D = packed.instantiate()
		self.check(placement.get_script() == editor_script, "House uses the editor script: %s" % entry["key"])
		self.check(placement.placed_res_bld_type == entry["key"], "House resolves its catalog type: %s" % entry["key"])
		container.add_child(placement)
		var children: Array[Node] = placement.get_children()
		var converted: Residence3D = placement.create_runtime()
		self.check(converted != null and converted.get_children() == children, "All authored children survive: %s" % entry["key"])
		self.check(converted.placed_res_bld_type == entry["key"], "Runtime retains catalog key: %s" % entry["key"])
		converted.free()
		placement.free()
	container.free()
	return true
