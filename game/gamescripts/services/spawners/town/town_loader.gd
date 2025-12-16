@icon("res://assets/icons/icon_town_white.png")
class_name TownPlacer extends Node

const MAP_TOWNS_FILEPATH_FORMAT = "res://world/%s/jsondata/towns.json"
const TOWN_ROOT_SCENE_PATH = "res://scenes/subscenes/town_root.tscn"
const LOAD_FROM_JSON = false

@export var storage: TownStore = TownStore.new()
@export_storage var res_bld_loader: ResidentialBldTypeLoader

signal towns_registered(towns: Array[TownData])

#region Initialization
func _enter_tree() -> void:
	Managers.towns = self
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))

func _on_map_spawned(_container: WorldMapScene) -> void:
	self.index_map_towns()
#endregion	

#region Town Spawning
func index_map_towns():
	Loggie.info("Loading towns from map")
	var map_towns_node: WorldTowns = GlobalState.world_container.find_child("Towns")
	for town_center: Town3D in map_towns_node.town_centers:
		self.storage.add_outter(town_center)
		self.storage.add(town_center.town)
	self.towns_registered.emit(map_towns_node.towns)
#endregion

#region Getters
func get_pos_on_terrain(posXZ: Vector2):
	var vec3: Vector3 = Vector3(posXZ.x, 0, posXZ.y)
	var terr_container: WorldMapScene = GlobalState.world_container
	return terr_container.get_pos_at_height(vec3)

func get_label_pos_at(posXZ: Vector2) -> Vector3:
	var offset: Vector3 = Vector3(0, 30, 0)
	var terrainPos: Vector3 = get_pos_on_terrain(posXZ)
	return terrainPos + offset
#endregion
