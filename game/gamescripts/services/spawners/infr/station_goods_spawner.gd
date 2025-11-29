@icon("res://assets/icons/icon_good_white.png")
class_name StationGoodsSpawner extends Node

const PASSENGER_SPAWN_EVENT = "station_passenger_generation"

func _ready() -> void:
	$SpawnPassengersTimer.timeout.connect(Callable(self, "_on_passenger_spawn_tick"))
	
#region Passengers
func spawn_rnd_passenger():
	Loggie.info("Spawning passenger")
	if ! GlobalState.loaded_map: return
	var rnd_outer_residence = OuterResBld.get_random()
	if rnd_outer_residence && rnd_outer_residence.res_bld_obj:
		var start_node_station: RailNodeStationData = rnd_outer_residence.connected_station
		if start_node_station:
			var spawned_res = SpawnedGood.new("passenger", 1)
			var target_res_bld_obj := OuterResBld.get_random().res_bld_obj
			spawned_res.target_location = target_res_bld_obj
			start_node_station.parent_station.add_spawned_good(spawned_res)
#endregion

#region Callbacks
func _on_passenger_spawn_tick():
	self.spawn_rnd_passenger()
#endregion
