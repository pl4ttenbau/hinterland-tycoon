## holds all connected residential buildings & industries to a single station
class_name StationConnections extends Resource

@export var parent: AbstractStation

@export_storage var industries: Array[StationIndustryConnection] = []
@export_storage var houses: Array[StationResidentialConnection] = []

signal new_connection(is_industry: bool)

func _init(_parent: AbstractStation) -> void:
	self.parent = _parent

#region Add Connection
func connect_house(house: Residence3D):
	self.houses.append(StationResidentialConnection.new(self.parent, house))
	self.new_connection.emit(false)

func connect_industry(industry: IndustryData):
	var ind_connection := StationIndustryConnection.new(self.parent, industry)
	self.industries.append(ind_connection)
	industry.station_connection = ind_connection
	self.new_connection.emit(true)
#endregion
