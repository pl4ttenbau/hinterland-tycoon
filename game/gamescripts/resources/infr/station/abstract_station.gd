@abstract 
@icon("res://assets/icons/icon_station_white.png")
class_name AbstractStation extends GameEntityData

@export var station_name: String

@export var town_num: int:
	get(): return town_num
	set(value):
		town_num = value
		# self.connect_to_town(value)

@export var station_type: String

## optional
@export var town_name: String

@export var hide_building: bool = false

@export var connections: StationConnections

func _init():
	super(Enums.EntityTypes.STATION)
	self.connections = StationConnections.new(self)

func connect_to_town(_town_num):
	# set town name if not manually done
	if ! self.town_name:
		self.town_name = TownData.get_town_by_num(self.town_num).town_name
	# connect to town
	var _connected_town := TownData.get_town_by_num(_town_num)
	if _connected_town:
		self.connected_town = _connected_town
		_connected_town.connect_new_station(self)
