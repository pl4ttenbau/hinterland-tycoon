@icon("res://assets/icons/icon_gears_white.png")
class_name WorldServicesCoordinator extends Node

signal services_initialized()
signal initialization_failed(error: int)
signal map_loading_failed(error: int)

var is_initialized: bool = false
var _registered_services: Dictionary = {}
var _connections: Array[Dictionary] = []

@onready var towns: TownPlacer = $Towns
@onready var town_buildings: TownBuildingHolder = $Towns/WorldTownBldPlacer
@onready var rails: RailsLoader = $Infr/Rails
@onready var forks: RailForkLoader = $Infr/Rails/RailForkLoader
@onready var rail_builder: NewRailBuilder = $Infr/Rails/NewRailBuilder
@onready var stations: StationsHolder = $Infr/Stations
@onready var interchanges: InterchangesLoader = $Infr/Interchanges
@onready var road_stops: RoadStopsLoader = $Infr/RoadStops
@onready var industry_connector: StationIndustriesConnector = $Infr/Stations/StationIndustryConnector
@onready var residence_connector: StationResidencesConnector = $Infr/Stations/StationResidenceConnector
@onready var passenger_spawner: StationGoodsSpawner = $Infr/Stations/StationGoodsSpawner
@onready var roads: RoadsLoader = $Infr/Roads
@onready var road_exit_connector: RoadIndustryExitConnector = $Infr/Roads/RoadIndustryExitConnector
@onready var vehicles: VehiclePlacer = $Vehicles
@onready var industries: IndustrySpawner = $Industries
@onready var depots: DepotLoader = $Depots
@onready var map_spawner: MapSpawner = $LoadedMap
@onready var world_timer: Timer = $LoadedMap/WorldUpdateTimer
@onready var passenger_timer: Timer = $Infr/Stations/StationGoodsSpawner/SpawnPassengersTimer

## GameSession calls this after types are ready. No service discovers dependencies
## during construction or tree entry; every registration precedes every connection.
func initialize() -> Error:
	if self.is_initialized:
		return OK
	if not self.is_node_ready() or not GameTypes.is_initialized:
		return self._fail(ERR_UNCONFIGURED)
	if is_instance_valid(Managers.world_services) and Managers.world_services != self:
		return self._fail(ERR_ALREADY_IN_USE)
	# Stage 1: validate the complete dependency set before publishing anything.
	self._collect_services()
	if not self._has_required_services():
		self._registered_services.clear()
		return self._fail(ERR_UNCONFIGURED)
	# Stage 2: publish dependencies, then connect all session listeners.
	self._register_services()
	self._wire_services()
	# Stage 3: start simulation and announce readiness only after wiring finishes.
	self._start_services()
	return OK

func _collect_services() -> void:
	self._registered_services = {
		&"towns": self.towns, &"town_buildings": self.town_buildings,
		&"rails": self.rails, &"forks": self.forks, &"stations": self.stations,
		&"interchanges": self.interchanges, &"road_stops": self.road_stops,
		&"roads": self.roads, &"vehicles": self.vehicles,
		&"industries": self.industries, &"depots": self.depots,
		&"map_spawner": self.map_spawner
	}

func _has_required_services() -> bool:
	var required: Array = self._registered_services.values() + [
		self.rail_builder, self.industry_connector, self.residence_connector,
		self.passenger_spawner, self.road_exit_connector,
		self.world_timer, self.passenger_timer
	]
	for service: Node in required:
		if not is_instance_valid(service):
			return false
	return true

## Application services (such as the map-list loader) are not session-owned.
func _register_services() -> void:
	for service_name: StringName in self._registered_services:
		Managers.set(service_name, self._registered_services[service_name])
	Managers.world_services = self
	self.town_buildings.has_res_bld_types_loaded = GameTypes.is_initialized

func _start_services() -> void:
	self.is_initialized = true
	self.world_timer.start()
	self.passenger_timer.start()
	# Publish globally before the local signal lets GameSession announce readiness.
	SignalBus.services_initialized.emit()
	self.services_initialized.emit()

#region Session signal wiring
func _wire_services() -> void:
	_wire_world_placement()
	_wire_towns()
	_wire_rails()
	_wire_stops_and_catchments()
	_wire_roads()
	_wire_depots()
	# Passenger configuration precedes the callback that loads and spawns the map.
	self._listen(SignalBus.map_selected, self.passenger_spawner._on_map_selected)
	self._listen(SignalBus.map_selected, self._on_map_selected)

## Preserve map_spawned listener order: towns/houses, rails, roads, industries.
## These callbacks place views; load_map_data separately orders their source data.
func _wire_world_placement() -> void:
	self._listen(SignalBus.map_spawned, self.towns._on_map_spawned)
	self._listen(SignalBus.map_spawned, self.town_buildings._on_map_spawned)
	self._listen(SignalBus.map_spawned, self.rails._on_map_spawned)
	self._listen(SignalBus.map_spawned, self.roads._on_world_spawned)
	self._listen(SignalBus.map_spawned, self.industries._on_terrain_loaded)

func _wire_towns() -> void:
	self._listen(SignalBus.res_bld_types_loaded, self.town_buildings._on_res_bld_types_loaded)
	self._listen(self.towns.towns_registered, self.town_buildings._on_map_towns_loaded)

func _wire_rails() -> void:
	self._listen(self.rails.track_storage.track_added, self.forks._on_track_loaded)
	self._listen(SignalBus.rails_spawned, self.forks._on_rails_spawned)
	self._listen(SignalBus.ui_mode_switched, self.rail_builder._on_ui_mode_changed)
	self._listen(SignalBus.terrain_click, self.rail_builder._on_terrain_click)
	self._listen(SignalBus.rails_spawned, self.residence_connector._on_rails_spawned)
	self._listen(SignalBus.rails_spawned, self.vehicles._on_rails_rails_spawned)

## Catchment connectors wait for both their station and building/industry inputs.
func _wire_stops_and_catchments() -> void:
	self._listen(self.towns.towns_registered, self.interchanges._on_map_towns_loaded)
	self._listen(self.towns.towns_registered, self.stations._on_map_towns_loaded)
	self._listen(self.towns.towns_registered, self.road_stops._on_map_towns_loaded)
	self._listen(SignalBus.stations_loaded, self.stations._on_stations_loaded)
	self._listen(SignalBus.node_station_links_spawned, self.industry_connector._on_node_station_links_spawned)
	self._listen(SignalBus.industries_spawned, self.industry_connector._on_industries_spawned)
	self._listen(SignalBus.stations_loaded, self.residence_connector._on_stations_loaded)
	self._listen(self.interchanges.stops_linked, self.residence_connector._on_stops_linked)
	self._listen(self.interchanges.stops_linked, self.industry_connector._on_stops_linked)
	self._listen(SignalBus.town_buildings_spawned, self.residence_connector._on_residences_placed)

func _wire_roads() -> void:
	self._listen(SignalBus.roads_spawned, self.road_exit_connector._on_roads_spawned)
	self._listen(SignalBus.roads_spawned, self.town_buildings._on_roads_spawned)
	self._listen(SignalBus.industries_spawned, self.road_exit_connector._on_industries_spawned)

## Depot definitions load after network data; their views spawn after road/rail views.
func _wire_depots() -> void:
	self._listen(SignalBus.rails_loaded, self.depots._on_rails_loaded)
	self._listen(SignalBus.rails_spawned, self.depots._on_rails_spawned)
	self._listen(SignalBus.roads_loaded, self.depots._on_roads_loaded)
	self._listen(SignalBus.roads_spawned, self.depots._on_roads_spawned)
#endregion

#region Ordered map loading
func load_map_data(map_key: String) -> Error:
	if not self.is_initialized:
		return ERR_UNCONFIGURED
	if self.stations.is_loaded or self.road_stops.is_loaded:
		return ERR_ALREADY_IN_USE
	# Stage 1: interchange parents must exist before either stop domain loads.
	GlobalState.selected_map_name = map_key
	var error: Error = self.interchanges.load_interchanges(map_key)
	if error != OK:
		return error
	# Stage 2: network data also triggers depot-definition loading.
	self.rails.load_rail_tracks()
	self.roads.load_roads()
	# Stage 3: validate references, then attach rail and road stops to their parents.
	error = self.interchanges.validate_anchors(self.rails.track_storage, self.roads.storage)
	if error != OK:
		return error
	error = self.stations.load_stations(self.interchanges)
	if error != OK:
		return error
	error = self.road_stops.load_stops(self.interchanges)
	if error != OK:
		return error
	self.interchanges.stops_linked.emit()
	return OK

func _on_map_selected(map_data: MapData) -> void:
	var error: Error = self.load_map_data(map_data.key)
	if error != OK:
		push_error("Map loading stopped before spawning: %s" % error_string(error))
		self.map_loading_failed.emit(error)
		return
	# Stage 4: only validated data may trigger terrain/world-view spawning.
	self.map_spawner.spawn_map(map_data)
#endregion

#region Listener ownership and cleanup
## Every connection is tracked so detaching the session releases global listeners.
func _listen(source: Signal, callback: Callable) -> void:
	source.connect(callback)
	self._connections.append({"source": source, "callback": callback})

func _fail(error: Error) -> Error:
	self.initialization_failed.emit(error)
	return error

## An unmounted session must stop listening even if its nodes have not been freed.
func _exit_tree() -> void:
	self.is_initialized = false
	_disconnect_services()
	_unregister_services()
	_stop_timers()

func _disconnect_services() -> void:
	for connection: Dictionary in self._connections:
		var source: Signal = connection["source"]
		var callback: Callable = connection["callback"]
		if not source.is_null() and source.is_connected(callback):
			source.disconnect(callback)
	self._connections.clear()

## Clear only registrations still owned by this session.
func _unregister_services() -> void:
	for service_name: StringName in self._registered_services:
		if Managers.get(service_name) == self._registered_services[service_name]:
			Managers.set(service_name, null)
	self._registered_services.clear()
	if Managers.world_services == self:
		Managers.world_services = null

func _stop_timers() -> void:
	if is_instance_valid(self.world_timer):
		self.world_timer.stop()
	if is_instance_valid(self.passenger_timer):
		self.passenger_timer.stop()

#endregion
