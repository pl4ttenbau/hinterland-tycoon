class_name Signals extends Node

@warning_ignore("unused_signal")
signal all_types_initialized()

#region World
@warning_ignore("unused_signal")
signal terrain_initialized(container: TerrainContainer)

@warning_ignore("unused_signal")
signal world_update()

@warning_ignore("unused_signal")
signal scene_root_ready()
#endregion

#region Vehicles
@warning_ignore("unused_signal")
signal vehicle_entered(vehicle: RailVehicle)

@warning_ignore("unused_signal")
signal vehicle_exited()
#endregion

#region Rails
@warning_ignore("unused_signal")
signal rail_spawned(rail_container: OuterRailTrack)

@warning_ignore("unused_signal")
signal rails_spawned(containers: Array[OuterRailTrack])
#endregion

#region Roads 
@warning_ignore("unused_signal")
signal road_spawned(road_container: OuterRoad)

@warning_ignore("unused_signal")
signal roads_spawned()
#endregion

#region Stations
@warning_ignore("unused_signal")
signal stations_spawned()
#endregion

#region Towns
@warning_ignore("unused_signal")
signal town_spawned(town: TownData)

@warning_ignore("unused_signal")
signal towns_spawned()

@warning_ignore("unused_signal")
signal towns_loaded()
#endregion

#region Industries
@warning_ignore("unused_signal")
signal industry_loaded(industry: Industry)

@warning_ignore("unused_signal")
signal industries_loaded(industries: Array[Industry])

@warning_ignore("unused_signal")
signal industry_spawned(container: OuterIndustry)
#endregion

#region Input
@warning_ignore("unused_signal")
signal mouse_click(event: InputEventMouseButton)

@warning_ignore("unused_signal")
signal collider_click(collider: ClickableCollider)

@warning_ignore("unused_signal")
signal unhandled_collider_click(collider: Node3D)
#endregion

#region UI
@warning_ignore("unused_signal")
signal ui_update_tick()

@warning_ignore("unused_signal")
signal action_menu_triggered(item: ActionMenuItem)
#endregion
