@icon("res://assets/icons/icon_gears_white.png")
extends Node

@export var triggers: WorldTriggers

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
