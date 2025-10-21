class_name RailStationConnections extends Resource

@export var parent: RailStationData
@export_storage var industries: Array[IndustryData] = []
@export_storage var houses: Array[OuterResBld] = []

signal new_connection(is_industry: bool)

func _init(_parent: RailStationData) -> void:
	self.parent = _parent

func connect_house(house: OuterResBld):
	self.houses.append(house)
	self.new_connection.emit(false)
	
func connect_industry(industry: IndustryData):
	self.industries.append(industry)
	industry.station_connection = self
	self.new_connection.emit(true)
	
func get_connected_amount_of(goods_key: String) -> int:
	var total_amount: int = 0
	for industry in self.industries:
		if ! industry.has_any(goods_key): continue
		total_amount += industry.storage.get_amount(goods_key)
	return total_amount
