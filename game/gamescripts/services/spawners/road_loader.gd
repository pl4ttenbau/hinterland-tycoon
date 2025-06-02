@icon("res://assets/icons/icon_road_white.png")
class_name RoadsLoader extends Node

const JSON_PATH = "res://world/jsondata/roads.json"
const NODES_GROUP = "Roads"

@export var roads: Array[RoadWay] = []
@export var containers: Array[OuterRoad] = []

signal roads_loaded(_roads: Array[RoadWay])
signal roads_spawned(_roads: Array[OuterRoad])

func load_roads() -> void:
	var roads_arr_str: String = FileAccess.get_file_as_string(JSON_PATH)
	for json_road in JSON.parse_string(roads_arr_str):
		self.roads.append(RoadWay.from_json(json_road))
	GlobalState.roads = self.roads
	self.roads_loaded.emit(self.roads)
	
func spawn_roads():
	for road in GlobalState.roads:
		spawn_road(road)
	# emit signals
	self.roads_spawned.emit(self.containers)
	SignalBus.roads_spawned.emit()
	
func spawn_road(road: RoadWay):
	var instanciated: OuterRoad = road.spawn()
	add_child(instanciated, true)
	self.containers.append(instanciated)
	add_to_group(NODES_GROUP)
	SignalBus.road_spawned.emit(instanciated)
		
func _ready() -> void:
	load_roads()
	spawn_roads()
	Loggie.info("roads precreated")

func _on_scene_ready() -> void:
	pass
