@icon("uid://r84qkk5fcxhq")
extends Node

# == PLAYER ==
@export var player: PlayerHead
@export var active_cam: Camera3D

# == PRE-WORLD-LOADING ==
@export var game_maps: Array[MapData]
@export var selected_map_name: String
@export var loaded_map: MapData 

# == STATIC ==
@export var towns: Array[TownData] = []

@export var industries: Array[IndustryData]
@export var world_container: WorldMapScene

@export var res_blds: Array[ResidenceBuildingData] = []

@export var res_bld_containers: Array[OuterResBld] = []
@export var ind_bld_containers: Array[OuterIndustry] = []

# == INFR ==
@export var tracks: Array[RailTrackData] = []
@export var outer_tracks: Array[OuterRailTrack] = []

@export var node_stations: Array[RailNodeStationData] = []
@export var station_objs: Array[RailStationData] = []

@export var depots: Array[RailDepotData] = []
@export var forks: Array[RailNodeForkData] = []

@export var roads: Array[RoadData] = []
@export var outer_roads: Array[OuterRoad] = []

@export var vehicles: Array[OuterRailVehicle] = []
