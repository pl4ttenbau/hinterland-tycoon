class_name Signals extends Node

# == WORLD ==
@warning_ignore("unused_signal")
signal terrain_initialized(container: TerrainContainer)

@warning_ignore("unused_signal")
signal world_update()

@warning_ignore("unused_signal")
signal scene_root_ready()

# == RAILS ==
@warning_ignore("unused_signal")
signal rail_spawned(rail_container: OuterRailTrack)

@warning_ignore("unused_signal")
signal rails_spawned(containers: Array[OuterRailTrack])

# == RAILS ==
@warning_ignore("unused_signal")
signal road_spawned(road_container: OuterRoad)

@warning_ignore("unused_signal")
signal roads_spawned()

# == STATIONS ==
@warning_ignore("unused_signal")
signal stations_spawned()

# == TOWNS == 
@warning_ignore("unused_signal")
signal town_spawned(town: TownResource)

@warning_ignore("unused_signal")
signal towns_spawned()

@warning_ignore("unused_signal")
signal towns_loaded()

# == UI ==
@warning_ignore("unused_signal")
signal ui_update_tick()
