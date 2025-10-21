@abstract 
@icon("res://assets/icons/icon_station_white.png")
class_name AbstractStation extends GoodsInventory

@export var station_name: String
@export var station_type: String
@export var town_name: String
@export var town_num: int
@export var hide_building: bool

@export var position: Vector3

@export var connections: StationConnections
