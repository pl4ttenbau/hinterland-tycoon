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
