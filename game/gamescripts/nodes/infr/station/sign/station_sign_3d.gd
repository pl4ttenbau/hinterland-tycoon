class_name StationSign3D extends Sprite3D

@export var node_station_link_3d: NodeStationLink3D

@export var parent_station: RailStationData

@export var station_inventory: GoodsInventory

@export var station_name: String:
	set(value):
		station_name = value
		%StationSignPanel.station_name = value

@export var station_sign_ui: StationSignPanel

@export_group("Current Good Amounts", "amount_")
@export var amount_passengers: float:
	set(value):
		amount_passengers = value
		self.station_sign_ui.passengers_amount = roundi(value)

@export var amount_cargo: float:
	set(value):
		amount_cargo = value
		self.station_sign_ui.cargo_amount = roundi(value)

#region Initialization
func _enter_tree() -> void:
	self.node_station_link_3d.node_station_changed.connect(Callable(self, "_on_node_station_changed"))

func _ready() -> void:
	# trigger NodeStationData registration, if the signal was emitted before this node existed
	self._on_node_station_changed(self.node_station_link_3d.node_station)
#endregion

#region Callbacks
func _on_node_station_changed(node_station: NodeStationLinkData):
	# save station name
	self.parent_station = node_station.parent_station
	self.station_name = self.parent_station.station_name
	# .. and inventory
	var station_3d: RailStation3D = self.node_station_link_3d.get_parent_station_3d()
	self.station_inventory = station_3d.get_inventory()
	if self.station_inventory:
		self.station_inventory.goods_change.connect(Callable(self, "_on_inventory_change"))

func _on_inventory_change():
	self.amount_passengers = self.station_inventory.storage.total_passengers
	self.amount_cargo = self.station_inventory.storage.total_cargo
#endregion
