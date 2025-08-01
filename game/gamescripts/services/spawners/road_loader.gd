@icon("res://assets/icons/icon_road_white.png")
class_name RoadsLoader extends Node

const JSON_PATH_FORMAT = "res://world/%s/jsondata/roads.json"
const NODES_GROUP = "Roads"
const MAX_VISIBLE_DIST := 200

@export var roads: Array[RoadData] = []
@export var containers: Array[OuterRoad] = []

signal roads_loaded(_roads: Array[RoadData])
signal roads_spawned(_roads: Array[OuterRoad])

func _enter_tree() -> void:
	Managers.roads = self
	SignalBus.world_update.connect(Callable(self, "_on_world_update"))
	SignalBus.map_spawned.connect(Callable(self, "_on_world_spawned"))

func load_roads() -> void:
	var full_json_path := JSON_PATH_FORMAT % GlobalState.loaded_map_name
	var roads_arr_str: String = FileAccess.get_file_as_string(full_json_path)
	for json_road in JSON.parse_string(roads_arr_str):
		self.roads.append(RoadData.from_json(json_road))
	GlobalState.roads = self.roads
	self.roads_loaded.emit(self.roads)
	
func spawn_roads():
	for road in GlobalState.roads:
		spawn_road(road)
	# emit signals
	self.roads_spawned.emit(self.containers)
	SignalBus.roads_spawned.emit()
	
func spawn_road(road: RoadData):
	var instanciated: OuterRoad = road.spawn()
	add_child(instanciated, true)
	self.containers.append(instanciated)
	add_to_group(NODES_GROUP)
	SignalBus.road_spawned.emit(instanciated)
		
func _ready() -> void:
	load_roads()
	Loggie.info("roads precreated")
	
func _on_world_spawned(_container: TerrainContainer):
	spawn_roads()

func _on_world_update() -> void:
	for container: OuterRoad in self.containers:
		var player: Node3D = %Player
		if player:
			var middle_pos: Vector3 = container.get_middle_pos()
			var dist = player.position.distance_to(middle_pos)
			if dist > MAX_VISIBLE_DIST: container.visible = false
			else: container.visible = true
