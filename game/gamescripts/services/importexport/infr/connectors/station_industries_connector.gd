@icon("res://assets/icons/icon_connect_white.png")
class_name StationIndustriesConnector extends Node

@export var has_connected: bool = false
const MAX_INDUSTRY_DIST: float = 200.0

func connect_industries() -> void:
	if has_connected or not is_instance_valid(Managers.interchanges) or not Managers.interchanges.is_loaded:
		return
	if GlobalState.industries.is_empty():
		return
	for interchange: InterchangeData in Managers.interchanges.interchanges:
		interchange.connections.clear_industries()
	for industry: IndustryData in GlobalState.industries:
		industry.station_connection = null
		var access: Dictionary = Managers.interchanges.find_access(industry.pos, MAX_INDUSTRY_DIST)
		if not access.is_empty():
			access.interchange.connections.connect_industry(industry, access.stops)
	has_connected = true

func _on_node_station_links_spawned() -> void:
	connect_industries()

func _on_stops_linked() -> void:
	connect_industries()

func _on_industries_spawned() -> void:
	connect_industries()
