extends Node

# == PLAYER ==
@export var player: PlayerHead
@export var active_cam: Camera3D

# == PRE-WORLD-LOADING ==
@export var game_maps: Array[MapData]
@export var loaded_map_name: String = "harzmountains"
@export var loaded_map: MapData 

# == STATIC ==
@export var towns: Array[TownData] = []

@export var industries: Array[IndustryData]
@export var terrain: TerrainContainer

@export var res_blds: Array[ResidenceBuildingData] = []

@export var res_bld_containers: Array[OuterResBld] = []
@export var ind_bld_containers: Array[OuterIndustry] = []

# == INFR ==
@export var tracks: Array[RailTrackData] = []
@export var outer_tracks: Array[OuterRailTrack] = []

@export var stations: Array[RailStationData] = []
@export var forks: Array[RailForkData] = []

@export var roads: Array[RoadData] = []
@export var outer_roads: Array[OuterRoad] = []

@export var vehicles: Array[RailVehicle] = []
