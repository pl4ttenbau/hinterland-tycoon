@icon("res://assets/icons/icon_good_white.png")
class_name StationGoodsSpawner extends Node

const LOG_SPAWNING: bool = true

@export var has_map_selected: bool = false

func _ready() -> void:
	$SpawnPassengersTimer.timeout.connect(Callable(self, "_on_passenger_spawn_tick"))
	SignalBus.map_selected.connect(Callable(self, "_on_map_selected"))
	
#region Passengers
func spawn_rnd_passenger():
	if ! self.has_map_selected: return
	if ! GlobalState.loaded_map: return
	var rnd_outer_residence = Residence3D.get_random()
	if rnd_outer_residence && rnd_outer_residence.res_bld_obj:
		var start_node_station: NodeStationLinkData = rnd_outer_residence.connected_station
		if start_node_station:
			var parent_station_num: int = start_node_station.parent_station_num
			var station3d: RailStation3D = Managers.stations.get_station_3d_with_num(parent_station_num)
			if start_node_station && station3d:
				# TODO: here we use to use targeted goods again
				# var spawned_res := SpawnedGood.new("passenger", 1, Residence3D.get_random().res_bld_obj)
				station3d.get_inventory().add_good_of("passenger")
				if LOG_SPAWNING:
					var town_name: String = station3d.station.connected_town.town_name
					var station_name: String = station3d.station.station_name
					Loggie.debug("Spawned passenger in station %s-%s" % [town_name, station_name])
			else:
				Loggie.error("Cannot find Station3D with Num %d" % parent_station_num)
#endregion

#region Callbacks
func _on_passenger_spawn_tick():
	self.spawn_rnd_passenger()
	
func _on_map_selected(_selected_map: MapData):
	self.has_map_selected = true
#endregion
