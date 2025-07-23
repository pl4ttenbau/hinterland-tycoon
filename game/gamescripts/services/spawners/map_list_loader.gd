@icon("res://assets/icons/icon_map_white.png")
class_name MapLoader extends Node

const MAP_FOLDER_PATH = "res://world/"

@export var map_list: Array[MapData] = []
@export var selected_map: MapData

func _enter_tree() -> void:
	Managers.map_list_loader = self

func _init() -> void:
	self.load_map_data()

func load_map_data():
	var map_folders := DirAccess.get_directories_at(MAP_FOLDER_PATH)
	for map_folder_name: String in map_folders:
		if map_folder_name == "heightdata": continue
		var full_folder_path := MAP_FOLDER_PATH + "/" + map_folder_name + \
			"/jsondata/"
		var map_info_file_path = full_folder_path + "mapinfo.json"
		var map_info_dict := self.get_map_info_dict(map_info_file_path)
		var map_obj = MapData.of_dict(map_info_dict)
		# add to lists & trigger signals
		self.add_map_to_lists(map_obj)
	Loggie.info("Map List loaded")
	# trigger signals & mock map selection
	SignalBus.map_list_loaded.emit(self.map_list)
	self.select_map()
		
func get_map_info_dict(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content_str: String = file.get_as_text()
	return JSON.parse_string(content_str)

func add_map_to_lists(map_obj: MapData):
	self.map_list.append(map_obj)
	GlobalState.game_maps.append(map_obj)
	
func select_map():
	GlobalState.loaded_map = self.get_map_data("demmin")
	SignalBus.map_selected.emit(GlobalState.loaded_map)
	
func get_map_data(map_key: String) -> MapData:
	for map_data: MapData in self.map_list:
		if map_data.key == map_key: return map_data
	Loggie.info("Cant load MapData \"%s\": does not exist" % map_key)
	return null
