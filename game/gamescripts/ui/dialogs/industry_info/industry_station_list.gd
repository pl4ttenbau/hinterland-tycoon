class_name IndustryStationList extends MarginContainer

@export var industry: IndustryData:
	set(value):
		industry = value
		_refresh()

func _refresh() -> void:
	var list: ItemList = %StationsTable
	list.clear()
	var connection: StationIndustryConnection = industry.station_connection if industry != null else null
	if connection != null and connection.interchange != null:
		list.add_item("%s · shared stock" % connection.interchange.interchange_name, null, false)
	elif connection != null and connection.station != null:
		list.add_item(connection.station.station_name, null, false)
	else:
		list.add_item("Industry stock", null, false)
