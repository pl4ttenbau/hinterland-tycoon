class_name StationConnections extends Resource

@export var parent: AbstractStation

@export_storage var industries: Array[StationIndustryConnection] = []
@export_storage var houses: Array[StationResidentialConnection] = []

signal new_connection(is_industry: bool)

func _init(_parent: AbstractStation) -> void:
	self.parent = _parent

#region Add Connection
func connect_house(house: OuterResBld):
	self.houses.append(StationResidentialConnection.new(self.parent, house))
	self.new_connection.emit(false)
	
func connect_industry(industry: IndustryData):
	var ind_connection := StationIndustryConnection.new(self.parent, industry)
	self.industries.append(ind_connection)
	industry.station_connection = ind_connection
	self.new_connection.emit(true)
#endregion

#region Get Connected
func get_connected_amount_of(goods_key: String) -> int:
	var total_amount: int = 0
	for industry in self.industries:
		if ! industry.has_any(goods_key): continue
		total_amount += industry.storage.get_amount(goods_key)
	return total_amount
	
func get_connected_storage() -> BaseGoodsStorage:
	var storage_obj := BaseGoodsStorage.new()
	for good_type: BaseGoodsType in GameTypes.resource_types:
		var amount := self.get_connected_amount_of(good_type.key)
		if amount > 1:
			storage_obj._set_amount(good_type.key, amount)
	return storage_obj
#endregion
