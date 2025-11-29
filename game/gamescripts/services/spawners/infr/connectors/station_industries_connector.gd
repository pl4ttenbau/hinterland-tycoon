@icon("res://assets/icons/icon_gears_white.png")
class_name StationIndustriesConnector extends Node

static var MAX_INDUSTRY_DIST = 200

func _enter_tree() -> void:
	SignalBus.stations_spawned.connect(Callable(self, "_on_stations_spawned"))

func connect_industries():
	Loggie.info("Connecting industries ..")
	for industry: IndustryData in GlobalState.industries:
		var closest_station: RailNodeStationData = null
		var closest_distance: float = 99999
		for station: RailNodeStationData in GlobalState.node_stations:
			var sq_dist: float = industry.pos.distance_squared_to(station.position)
			if sq_dist <= closest_distance:
				closest_station = station
				closest_distance = sq_dist
		if closest_station && closest_distance > MAX_INDUSTRY_DIST:
			closest_station.connect_industry(industry)

#region Callbacks
func _on_stations_spawned():
	pass
#endregion
