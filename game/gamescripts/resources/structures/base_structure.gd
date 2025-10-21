class_name BaseStructure extends GoodsInventory

@export var town_num: int
@export var bld_type: AbstractBldType
@export var is_registered: bool = false

@export_storage var connected_station: RailStationData
