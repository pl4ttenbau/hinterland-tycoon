class_name StationPlatformSurface extends MeshInstance3D

@export var station_building: StationBuilding3D

@export var station_inventory: GoodsInventory

func _ready() -> void:
	if !Engine.is_editor_hint():
		self.visible = false
		self.register_station_inventory()
		
## add inventory & listen to change
func register_station_inventory():
	var found_station_inventory: GoodsInventory = self.get_inventory()
	if found_station_inventory:
		self.station_inventory = found_station_inventory
		found_station_inventory.goods_change.connect(Callable(self, "_on_inventory_goods_changed"))

func set_passenger_count(passengers: int):
	self.get_scatterer().count = passengers

func get_passengers_count() -> int:
	return self.get_scatterer().count

#region Getters
func get_scatterer() -> MultiMeshScatter:
	if !self.has_node("MultiMeshScatter"):
		Loggie.error("Station platform %s has no Platform MultiMeshScatter" % self.name)
		return null
	return $MultiMeshScatter

func get_inventory() -> GoodsInventory:
	var node_link_3d: NodeStationLink3D = self.station_building.node_link_3d
	if node_link_3d:
		var station_num: int = node_link_3d.node_station.parent_station_num
		var station_3d: RailStation3D = Managers.stations.get_station_3d_with_num(station_num)
		return station_3d.get_inventory()
	Loggie.error("Cannot get inventory of station from platform %s" % self.name)
	return null
#endregion

#region Callbacks
func _on_inventory_goods_changed():
	var curr_passengers: int = roundi(self.station_inventory.get_amount("passenger"))
	var displayed_passengers: int = self.get_passengers_count()
	if curr_passengers != displayed_passengers:
		self.set_passenger_count(curr_passengers)
#endregion
