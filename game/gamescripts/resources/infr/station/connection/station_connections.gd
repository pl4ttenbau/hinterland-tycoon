## Building membership belongs to an interchange; standalone stations remain
## supported for legacy callers until connection Resources become packed IDs.
class_name StationConnections extends Resource

## Held weakly: the parent station or interchange owns these connections.
var parent: GameEntityData:
	set(value): _parent = weakref(value) if value != null else null
	get(): return _parent.get_ref() if _parent != null else null
var _parent: WeakRef = null

@export_storage var industries: Array[StationIndustryConnection] = []
@export_storage var houses: Array[StationResidentialConnection] = []

signal new_connection(is_industry: bool)

func _init(_parent: GameEntityData = null) -> void:
	self.parent = _parent

#region Add Connection
func connect_house(house: Residence3D, reachable: Array[AbstractStation] = []):
	for existing: StationResidentialConnection in houses:
		if existing.house == house:
			return
	self.houses.append(StationResidentialConnection.new(self.parent, house, reachable))
	self.new_connection.emit(false)

func connect_industry(industry: IndustryData, reachable: Array[AbstractStation] = []):
	for existing: StationIndustryConnection in industries:
		if existing.industry == industry:
			industry.station_connection = existing
			return
	var ind_connection := StationIndustryConnection.new(self.parent, industry, reachable)
	self.industries.append(ind_connection)
	industry.station_connection = ind_connection
	self.new_connection.emit(true)

func clear_houses() -> void:
	for connection: StationResidentialConnection in houses:
		if is_instance_valid(connection.house) and connection.house.res_bld_obj != null:
			var data: ResidenceBuildingData = connection.house.res_bld_obj
			if data.connected_interchange == connection.interchange:
				data.connected_interchange = null
				data.reachable_stops.clear()
	houses.clear()

func clear_industries() -> void:
	for connection: StationIndustryConnection in industries:
		if connection.industry != null and connection.industry.station_connection == connection:
			connection.industry.station_connection = null
	industries.clear()
#endregion
