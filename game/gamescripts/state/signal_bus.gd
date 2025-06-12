class_name Signals extends Node

@warning_ignore("unused_signal")
signal all_types_initialized()

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

# == INDUSTRIES ==
@warning_ignore("unused_signal")
signal industry_loaded(industry: Industry)

@warning_ignore("unused_signal")
signal industries_loaded(industries: Array[Industry])

@warning_ignore("unused_signal")
signal industry_spawned(container: OuterIndustry)

# == INPUT ==
@warning_ignore("unused_signal")
signal mouse_click(event: InputEventMouseButton)

@warning_ignore("unused_signal")
signal collider_click(collider: ClickableCollider)


@warning_ignore("unused_signal")
signal unhandled_collider_click(collider: Node3D)

# == UI ==
@warning_ignore("unused_signal")
signal ui_update_tick()
