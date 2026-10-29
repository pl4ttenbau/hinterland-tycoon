@icon("res://assets/icons/icon_connect_white.png")
class_name StationIndustriesConnector extends Node

@export var has_connected: bool = false

static var MAX_INDUSTRY_DIST = 200

func _init() -> void:
	SignalBus.node_station_links_spawned.connect(Callable(self, "_on_node_station_links_spawned"))
	SignalBus.industries_spawned.connect(Callable(self, "_on_industries_spawned"))
	
func _ready() -> void:
	self.connect_industries()

func connect_industries():
	if self.has_connected: return
	if GlobalState.industries.is_empty(): return
	if Managers.stations.node_stations_storage.get_all().is_empty(): return
	Loggie.info("Connecting industries ..")
	var connected_ind_counter: int = 0
	for industry: IndustryData in GlobalState.industries:
		var closest_station_link: NodeStationLinkData = null
		var closest_distance: float = 99999
		var station_links: Array[NodeStationLinkData] = Managers.stations.node_stations_storage.get_all()
		for node_station_link: NodeStationLinkData in station_links:
			var sq_dist: float = industry.pos.distance_squared_to(node_station_link.position)
			if sq_dist <= closest_distance:
				closest_station_link = node_station_link
				closest_distance = sq_dist
		if closest_station_link && closest_distance > MAX_INDUSTRY_DIST:
			var parent_station: RailStationData = closest_station_link.parent_station
			parent_station.connections.connect_industry(industry)
			connected_ind_counter += 1
	self.has_connected = true
	Loggie.info("Connected %d industries to station" % connected_ind_counter)

#region Callbacks
func _on_node_station_links_spawned():
	self.connect_industries()

func _on_industries_spawned():
	self.connect_industries()
#endregion
