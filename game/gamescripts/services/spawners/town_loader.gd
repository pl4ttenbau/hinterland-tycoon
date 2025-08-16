@icon("res://assets/icons/icon_town_white.png")
class_name TownPlacer extends Node

const MAP_TOWNS_FILEPATH_FORMAT = "res://world/%s/jsondata/towns.json"
const TOWN_ROOT_SCENE_PATH = "res://scenes/subscenes/town_root.tscn"

@export var towns: Array[TownData] = []
@export var town_centers: Array[TownCenter] = []
@export_storage var res_bld_loader: ResidentialBldTypeLoader

func _enter_tree() -> void:
	Managers.towns = self
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))
	
func _ready() -> void:
	self.load_towns()

func _on_map_spawned(_container: TerrainContainer) -> void:
	self.spawn_towns()
	
func parse_towns_json(_json_str: String) -> Array[TownData]:
	var json_arr = JSON.parse_string(_json_str) as Array[Dictionary]
	var town_obj_arr: Array[TownData] = []
	for town_values_dict: Dictionary in json_arr:
		town_obj_arr.append(TownData.from_json(town_values_dict))
	return town_obj_arr
				
func load_towns():
	var town_file_path = MAP_TOWNS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var town_json_str = FileAccess.get_file_as_string(town_file_path)
	for parsed_town: TownData in parse_towns_json(town_json_str):
		# save town itself in lists
		self.towns.append(parsed_town)
		GlobalState.towns.append(parsed_town)
	SignalBus.towns_loaded.emit()
	
func spawn_towns():
	for town: TownData in self.towns:
		spawn_town(town)
	SignalBus.towns_spawned.emit()
	
func spawn_town(_town: TownData) -> TownData:
	var sceneRes: Resource = ResourceLoader.load(TOWN_ROOT_SCENE_PATH) as PackedScene
	var town_center: TownCenter = sceneRes.instantiate()
	town_center.town = _town
	town_center.position = get_pos_on_terrain(_town.pos_xz)
	# add as child and to center list
	add_child(town_center)
	self.town_centers.append(town_center)
	# emit signal
	SignalBus.town_spawned.emit(_town)
	return _town

#region Getters
func get_pos_on_terrain(posXZ: Vector2):
	var vec3: Vector3 = Vector3(posXZ.x, 0, posXZ.y)
	var terr_container: TerrainContainer = GlobalState.terrain
	return terr_container.get_pos_at_height(vec3)

func get_label_pos_at(posXZ: Vector2) -> Vector3:
	var offset: Vector3 = Vector3(0, 30, 0)
	var terrainPos: Vector3 = get_pos_on_terrain(posXZ)
	return terrainPos + offset

func get_town_center(town_num: int) -> TownCenter:
	for town_center: TownCenter in self.town_centers:
		if town_center.town && town_center.town.num == town_num:
			return town_center
	Loggie.warn("Cannot fimd Town with num %d" % town_num)
	return null
#endregion
