@icon("res://assets/icons/icon_gears_white.png")
extends Node

## Session-scoped services are published together by their coordinator.
var world_services: WorldServicesCoordinator

func are_world_services_initialized() -> bool:
	return is_instance_valid(self.world_services) and self.world_services.is_initialized

#region Map & Terrain
@export var map_list_loader: MapLoader
@export var map_spawner: MapSpawner

@export var deco: DecoSpawner
#endregion

#region Infrastructure
@export var rails: RailsLoader
@export var forks: RailForkLoader
@export var roads: RoadsLoader
@export var stations: StationsHolder

@export var depots: DepotLoader
@export var vehicles: VehiclePlacer
#endregion

#region Locations
@export var towns: TownPlacer
@export var town_buildings: TownBuildingHolder

@export var industries: IndustrySpawner
#endregion
