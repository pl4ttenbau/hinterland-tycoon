@abstract
class_name AbstractStructure extends GoodsInventory

@export var town_num: int
@export var bld_type: AbstractBldType
@export var is_registered: bool = false

#region Connections
@export_storage var connected_station: RailNodeStationData
@export_storage var road_exit: RoadNode
#endregion
