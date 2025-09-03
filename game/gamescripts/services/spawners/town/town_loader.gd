@icon("res://assets/icons/icon_town_white.png")
class_name TownPlacer extends Node

const MAP_TOWNS_FILEPATH_FORMAT = "res://world/%s/jsondata/towns.json"
const TOWN_ROOT_SCENE_PATH = "res://scenes/subscenes/town_root.tscn"
const LOAD_FROM_JSON = false

@export var storage: TownStore = TownStore.new()
@export_storage var res_bld_loader: ResidentialBldTypeLoader

#region Initialization
func _enter_tree() -> void:
	Managers.towns = self
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))
	
func _ready() -> void:
	self.load_towns()

func _on_map_spawned(_container: TerrainContainer) -> void:
	self.spawn_towns()
#endregion	

#region Town Loading
func load_towns():
	if  !LOAD_FROM_JSON: return
	var town_file_path = MAP_TOWNS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var town_json_str = FileAccess.get_file_as_string(town_file_path)
	var json_arr_dict: Array = JSON.parse_string(town_json_str) as Array
	for parsed_town: TownData in TownMapper.town_list_from_dict_arr(json_arr_dict):
		self.storage.add(parsed_town)
	SignalBus.towns_loaded.emit()
#endregion

#region Town Spawning
func spawn_towns():
	if LOAD_FROM_JSON:
		Loggie.info("Loading towns from json")
		for town: TownData in self.storage.get_all():
			spawn_town(town)
		SignalBus.towns_spawned.emit()
	else:
		Loggie.info("Loading towns from map")
		var map_towns: Node = GlobalState.world_container.find_child("Towns")
		for towns_child: Node in map_towns.get_children():
			if towns_child is TownCenter:
				self.storage.add_outter(towns_child)
				self.storage.add(towns_child.town)
				GlobalState.towns.append(towns_child.town)
	
func spawn_town(_town: TownData) -> TownData:
	var sceneRes: Resource = ResourceLoader.load(TOWN_ROOT_SCENE_PATH) as PackedScene
	var town_center: TownCenter = sceneRes.instantiate()
	town_center.town = _town
	town_center.position = get_pos_on_terrain(_town.pos_xz)
	# add as child and to center list
	add_child(town_center)
	self.storage.add_outter(town_center)
	# emit signal
	SignalBus.town_spawned.emit(_town)
	return _town
#endregion

#region Getters
func get_pos_on_terrain(posXZ: Vector2):
	var vec3: Vector3 = Vector3(posXZ.x, 0, posXZ.y)
	var terr_container: TerrainContainer = GlobalState.world_container
	return terr_container.get_pos_at_height(vec3)

func get_label_pos_at(posXZ: Vector2) -> Vector3:
	var offset: Vector3 = Vector3(0, 30, 0)
	var terrainPos: Vector3 = get_pos_on_terrain(posXZ)
	return terrainPos + offset
#endregion
