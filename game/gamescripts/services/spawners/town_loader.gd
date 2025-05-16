extends Node3D

@onready var terrain_container: TerrainContainer = %TerrainContainer

@export var towns: Array[Town] = []
const json_path = "res://world/jsondata/towns.json"
const scene_path = "res://scenes/subscenes/town_root.tscn"

func _on_scene_ready() -> void:
	load_towns()
	
func parse_towns_json(_json_str: String) -> Array[Town]:
	var json_arr = JSON.parse_string(_json_str) as Array[Dictionary]
	if !json_arr:
		push_warning("Couldnt load Town from \"%s\"" % _json_str)
		return []
	var town_obj_arr: Array[Town] = []
	for town_values_dict: Dictionary in json_arr:
		town_obj_arr.append(Town.from_json(town_values_dict))
	return town_obj_arr
				
func load_towns():
	var town_json_str = FileAccess.get_file_as_string(json_path)
	for parsed_town: Town in parse_towns_json(town_json_str):
		var spawned_town: Town = spawn_town(parsed_town)
		add_town(spawned_town)
	SignalBus.towns_loaded.emit()
	
func add_town(_town: Town):
	self.towns.append(_town)
	GlobalState.towns.append(_town)
	
func spawn_town(_town: Town) -> Town:
	var sceneRes: Resource = ResourceLoader.load(scene_path) as PackedScene
	var town_container_node: Node3D = sceneRes.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	add_child(town_container_node)
	town_container_node.name = str(_town)
	town_container_node.town = _town
	town_container_node.position = get_pos_on_terrain(_town.pos_xz)
	var town_label: Label3D = town_container_node.get_child(0)
	town_label.text = _town.town_name
	# emit signal
	SignalBus.town_spawned.emit(_town)
	return _town
	
func get_pos_on_terrain(posXZ: Vector2):
	var vec3: Vector3 = Vector3(posXZ.x, 0, posXZ.y)
	if terrain_container:
		return terrain_container.get_pos_at_height(vec3)
	return null

func get_label_pos_at(posXZ: Vector2) -> Vector3:
	var offset: Vector3 = Vector3(0, 30, 0)
	var terrainPos: Vector3 = get_pos_on_terrain(posXZ)
	return terrainPos + offset
