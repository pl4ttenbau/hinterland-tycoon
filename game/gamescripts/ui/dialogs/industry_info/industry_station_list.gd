class_name IndustryStationList extends MarginContainer

@export var industry: IndustryData:
	get(): return industry
	set(value):
		industry = value
		self.build_table()

func build_table():
	# get rid of default item
	%StationsTable.remove_item(0)
	# and add correct one (railway only now)
	var station_conn: StationIndustryConnection = self.industry.station_connection
	if station_conn:
		var station_name = station_conn.station.station_name
		%StationsTable.add_item(station_name, null, false)
	else:
		%StationsTable.add_item("none", null, false)
