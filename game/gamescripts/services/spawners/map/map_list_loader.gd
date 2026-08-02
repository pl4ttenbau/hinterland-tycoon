@icon("res://assets/icons/icon_map_white.png")
class_name MapLoader extends Node

@export var map_list: Array[MapData] = []
@export var selected_map: MapData

func _enter_tree() -> void:
	Managers.map_list_loader = self

func _init() -> void:
	self.load_map_data()

func load_map_data():
	var map_folders := DirAccess.get_directories_at(MapData.WORLDS_FOLDER)
	for map_folder_name: String in map_folders:
		if map_folder_name == "default": continue
		var map_data: MapData = MapData.parse(map_folder_name)
		if map_data:
			self.add_map_to_lists(map_data)
	Loggie.info("Map List loaded")
	# trigger signals & mock map selection
	GlobalState.game_maps = self.map_list
	SignalBus.map_list_loaded.emit(self.map_list)
	# self.select_map()

func add_map_to_lists(map_obj: MapData):
	self.map_list.append(map_obj)
	GlobalState.game_maps.append(map_obj)

func select_map():
	GlobalState.loaded_map = self.get_map_data(GlobalState.selected_map_name)
	SignalBus.map_selected.emit(GlobalState.loaded_map)

func get_map_data(map_key: String) -> MapData:
	for map_data: MapData in self.map_list:
		if map_data.key == map_key: return map_data
	Loggie.info("Cant load MapData \"%s\": does not exist" % map_key)
	return null
