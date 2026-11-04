@abstract
class_name AbstractStructure extends GameEntityData

@export var town_num: int
@export var bld_type: AbstractBldType
@export var is_registered: bool = false

#region Connections
@export_storage var connected_station: NodeStationLinkData
@export_storage var connected_interchange: InterchangeData
@export_storage var reachable_stops: Array[AbstractStation] = []
@export_storage var road_exit: RoadNode
#endregion
