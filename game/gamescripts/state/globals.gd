extends Node

# == PLAYER ==
@export var player: PlayerHead

# == STATIC ==
@export var towns: Array[TownResource] = []
@export var terrain: TerrainContainer

@export var res_bld_containers: Array[Node3D] = []
@export var ind_bld_containers: Array[Node3D] = []

# == INFR ==
@export var tracks: Array[RailTrack] = []
@export var stations: Array[RailStationResource] = []
@export var forks: Array[RailFork] = []

@export var roads: Array[RoadWay] = []
