@icon("res://assets/icons/icon_road_white.png")
class_name RoadsLoader extends Node

const JSON_PATH_FORMAT = "res://world/%s/jsondata/roads.json"
const NODES_GROUP = "Roads"
const MAX_VISIBLE_DIST := 200

@export var storage: RoadStore = RoadStore.new()

signal roads_loaded(_roads: Array[RoadData])
signal roads_spawned(_roads: Array[OuterRoad])

func _enter_tree() -> void:
	Managers.roads = self
	SignalBus.map_spawned.connect(Callable(self, "_on_world_spawned"))
	SignalBus.map_selected.connect(Callable(self, "_on_map_selected"))

#region Road Loading
func load_roads() -> void:
	var full_json_path := JSON_PATH_FORMAT % GlobalState.selected_map_name
	var roads_arr_str: String = FileAccess.get_file_as_string(full_json_path)
	for json_road in JSON.parse_string(roads_arr_str):
		self.storage.add(RoadMapper.road_from_data_json(json_road))
	self.roads_loaded.emit(self.storage.get_all())
#endregion
	
#region Road Spawning
func spawn_roads():
	for road in self.storage.get_all():
		spawn_road(road)
	# emit signals
	self.roads_spawned.emit(self.storage.get_containers())
	SignalBus.roads_spawned.emit()
	
func spawn_road(road: RoadData):
	var instanciated: OuterRoad = road.spawn()
	add_child(instanciated, true)
	self.storage.add_container(instanciated)
	SignalBus.road_spawned.emit(instanciated)
#endregion

#region Callbacks
func _on_world_spawned(_container: WorldMapScene):
	spawn_roads()

func _on_map_selected(_selected_map: MapData):
	self.load_roads()
#endregion
