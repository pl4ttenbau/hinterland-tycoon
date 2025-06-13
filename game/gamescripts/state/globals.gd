extends Node

# == PLAYER ==
@export var player: PlayerHead
@export var active_cam: Camera3D

# == STATIC ==
@export var towns: Array[TownResource] = []
@export var industries: Array[Industry]
@export var terrain: TerrainContainer

@export var res_bld_containers: Array[OuterResBld] = []
@export var ind_bld_containers: Array[OuterIndustry] = []

# == INFR ==
@export var tracks: Array[RailTrack] = []
@export var stations: Array[RailStationResource] = []
@export var forks: Array[RailFork] = []

@export var roads: Array[RoadWay] = []

@export var vehicles: Array[RailVehicle] = []
