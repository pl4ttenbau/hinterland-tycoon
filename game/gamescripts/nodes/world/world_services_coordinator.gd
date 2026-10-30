@icon("res://assets/icons/icon_gears_white.png")
class_name WorldServicesCoordinator extends Node

signal services_initialized()
signal initialization_failed(error: int)

var is_initialized: bool = false
var _registered_services: Dictionary = {}
var _connections: Array[Dictionary] = []

@onready var towns: TownPlacer = $Towns
@onready var town_buildings: TownBuildingHolder = $Towns/WorldTownBldPlacer
@onready var rails: RailsLoader = $Infr/Rails
@onready var forks: RailForkLoader = $Infr/Rails/RailForkLoader
@onready var rail_builder: NewRailBuilder = $Infr/Rails/NewRailBuilder
@onready var stations: StationsHolder = $Infr/Stations
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
	self._registered_services = {
		&"towns": self.towns, &"town_buildings": self.town_buildings,
		&"rails": self.rails, &"forks": self.forks, &"stations": self.stations,
		&"roads": self.roads, &"vehicles": self.vehicles,
		&"industries": self.industries, &"depots": self.depots,
		&"map_spawner": self.map_spawner
	}
	var required: Array = self._registered_services.values() + [
		self.rail_builder, self.industry_connector, self.residence_connector,
		self.passenger_spawner, self.road_exit_connector,
		self.world_timer, self.passenger_timer
	]
	for service: Node in required:
		if not is_instance_valid(service):
			self._registered_services.clear()
			return self._fail(ERR_UNCONFIGURED)
	for service_name: StringName in self._registered_services:
		Managers.set(service_name, self._registered_services[service_name])
	Managers.world_services = self
	self.town_buildings.has_res_bld_types_loaded = GameTypes.is_initialized
	self._wire_services()
	self.is_initialized = true
	self.world_timer.start()
	self.passenger_timer.start()
	# Publish globally before the local signal lets GameSession announce readiness.
	SignalBus.services_initialized.emit()
	self.services_initialized.emit()
	return OK

func _wire_services() -> void:
	# Keep the existing map-loading sequence, now explicitly independent of tree order.
	self._listen(SignalBus.map_spawned, self.towns._on_map_spawned)
	self._listen(SignalBus.map_spawned, self.town_buildings._on_map_spawned)
	self._listen(SignalBus.res_bld_types_loaded, self.town_buildings._on_res_bld_types_loaded)
	self._listen(self.towns.towns_registered, self.town_buildings._on_map_towns_loaded)
	self._listen(SignalBus.map_spawned, self.rails._on_map_spawned)
	self._listen(SignalBus.map_selected, self.rails._on_map_selected)
	self._listen(self.rails.track_storage.track_added, self.forks._on_track_loaded)
	self._listen(SignalBus.rails_spawned, self.forks._on_rails_spawned)
	self._listen(SignalBus.ui_mode_switched, self.rail_builder._on_ui_mode_changed)
	self._listen(SignalBus.terrain_click, self.rail_builder._on_terrain_click)
	self._listen(self.towns.towns_registered, self.stations._on_map_towns_loaded)
	self._listen(SignalBus.stations_loaded, self.stations._on_stations_loaded)
	self._listen(SignalBus.node_station_links_spawned, self.industry_connector._on_node_station_links_spawned)
	self._listen(SignalBus.industries_spawned, self.industry_connector._on_industries_spawned)
	self._listen(SignalBus.stations_loaded, self.residence_connector._on_stations_loaded)
	self._listen(SignalBus.town_buildings_spawned, self.residence_connector._on_residences_placed)
	self._listen(SignalBus.rails_spawned, self.residence_connector._on_rails_spawned)
	self._listen(SignalBus.map_selected, self.passenger_spawner._on_map_selected)
	self._listen(SignalBus.map_spawned, self.roads._on_world_spawned)
	self._listen(SignalBus.map_selected, self.roads._on_map_selected)
	self._listen(SignalBus.roads_spawned, self.road_exit_connector._on_roads_spawned)
	self._listen(SignalBus.industries_spawned, self.road_exit_connector._on_industries_spawned)
	self._listen(SignalBus.rails_spawned, self.vehicles._on_rails_rails_spawned)
	self._listen(SignalBus.map_spawned, self.industries._on_terrain_loaded)
	self._listen(SignalBus.rails_loaded, self.depots._on_rails_loaded)
	self._listen(SignalBus.rails_spawned, self.depots._on_rails_spawned)
	# Terrain spawning is last: all data loaders have received map_selected first.
	self._listen(SignalBus.map_selected, self.map_spawner._on_map_selected)

func _listen(source: Signal, callback: Callable) -> void:
	source.connect(callback)
	self._connections.append({"source": source, "callback": callback})

func _fail(error: Error) -> Error:
	self.initialization_failed.emit(error)
	return error

## An unmounted session must stop listening even if its nodes have not been freed.
func _exit_tree() -> void:
	self.is_initialized = false
	for connection: Dictionary in self._connections:
		var source: Signal = connection["source"]
		var callback: Callable = connection["callback"]
		if not source.is_null() and source.is_connected(callback):
			source.disconnect(callback)
	self._connections.clear()
	for service_name: StringName in self._registered_services:
		if Managers.get(service_name) == self._registered_services[service_name]:
			Managers.set(service_name, null)
	self._registered_services.clear()
	if Managers.world_services == self:
		Managers.world_services = null
	if is_instance_valid(self.world_timer):
		self.world_timer.stop()
	if is_instance_valid(self.passenger_timer):
		self.passenger_timer.stop()
