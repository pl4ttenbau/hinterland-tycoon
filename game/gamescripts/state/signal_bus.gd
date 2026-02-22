class_name Signals extends Node

@warning_ignore("unused_signal")
signal all_types_initialized()

@warning_ignore("unused_signal")
signal map_list_loaded(map_list: Array[MapData])

@warning_ignore("unused_signal")
signal map_selected(map_obj: MapData)

#region UI
@warning_ignore("unused_signal")
signal dialog_vehicle_selection(veh_type_key: String)
#endregion

@warning_ignore("unused_signal")
signal ui_mode_switched(mode: Enums.UiMode)

#region World
@warning_ignore("unused_signal")
signal terrain_initialized(container: WorldMapScene)

@warning_ignore("unused_signal")
signal world_update()

@warning_ignore("unused_signal")
signal scene_root_ready()

@warning_ignore("unused_signal")
signal map_spawned(container: WorldMapScene)
#endregion

#region Vehicles
@warning_ignore("unused_signal")
signal train_entered(train3d: Train3D)

@warning_ignore("unused_signal")
signal train_exited()
#endregion

#region Rails
@warning_ignore("unused_signal")
signal rails_loaded(rails: Array[RailTrackData])

@warning_ignore("unused_signal")
signal rail_spawned(rail_container: RailTrack3D)

@warning_ignore("unused_signal")
signal rails_spawned(containers: Array[RailTrack3D])

@warning_ignore("unused_signal")
signal fork_changed(fork: RailNodeForkData)
#endregion

#region Roads 
@warning_ignore("unused_signal")
signal road_spawned(road_container: RoadWay3D)

@warning_ignore("unused_signal")
signal roads_spawned()
#endregion

#region Stations
@warning_ignore("unused_signal")
signal stations_loaded(station_objs: Array[RailStationData])

@warning_ignore("unused_signal")
signal stations_spawned()
#endregion

#region Residential Buildings
@warning_ignore("unused_signal")
signal res_bld_types_loaded()

@warning_ignore("unused_signal")
signal town_buildings_spawned()
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
signal industry_loaded(industry: IndustryData)

@warning_ignore("unused_signal")
signal industries_loaded(industries: Array[IndustryData])

@warning_ignore("unused_signal")
signal industry_spawned(container: Industry3D)

@warning_ignore("unused_signal")
signal industries_spawned()
#endregion

#region Input
@warning_ignore("unused_signal")
signal mouse_click(event: InputEventMouseButton)

@warning_ignore("unused_signal")
signal collider_click(collider: ClickableCollider)

@warning_ignore("unused_signal")
signal unhandled_collider_click(collider: Node3D)

@warning_ignore("unused_signal")
signal terrain_click(pos: Vector3)
#endregion

#region UI
@warning_ignore("unused_signal")
signal ui_update_tick()

@warning_ignore("unused_signal")
signal action_menu_triggered(item: ActionMenuItem)
#endregion
