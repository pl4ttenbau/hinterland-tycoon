extends Node

#region Map & Terrain
@export var map_list_loader: MapLoader
@export var map_spawner: MapSpawner
#endregion

#region Infrastructure
@export var rails: RailsLoader
@export var roads: RoadsLoader
@export var stations: StationsHolder

@export var vehicles: VehiclePlacer
#endregion

#region Locations
@export var towns: TownPlacer
@export var town_buildings: TownBuildingHolder

@export var industries: IndustrySpawner
#endregion
