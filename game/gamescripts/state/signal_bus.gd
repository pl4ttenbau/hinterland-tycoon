class_name Signals extends Node

# == RAILS ==
signal rail_spawned(rail_container: OuterRailTrack)
signal rails_spawned()

# == STATIONS ==
signal stations_spawned()

# == TOWNS == 
signal town_spawned(town: TownResource)
signal towns_spawned()
signal towns_loaded()

# == TERRAIN ==
signal terrain_initialized(rail_container: TerrainContainer)
