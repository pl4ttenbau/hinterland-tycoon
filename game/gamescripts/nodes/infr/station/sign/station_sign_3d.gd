class_name StationSign3D extends Sprite3D

@export var node_station_link_3d: NodeStationLink3D

@export var station_inventory: GoodsInventory

@export var station_name: String:
	set(value):
		station_name = value
		%StationSignPanel.station_name = value

@export var station_res_amount: float

#region Initialization
func _enter_tree() -> void:
	self.node_station_link_3d.node_station_changed.connect(Callable(self, "_on_node_station_changed"))

func _ready() -> void:
	self._on_node_station_changed(self.node_station_link_3d.node_station)
#endregion

func _on_node_station_changed(node_station: NodeStationLinkData):
	# save station name
	var parent_station_data: RailStationData = node_station.parent_station
	self.station_name = parent_station_data.station_name
	# .. and inventory
	var station_3d: RailStation3D = self.node_station_link_3d.get_parent_station_3d()
	self.station_inventory = station_3d.get_inventory()
