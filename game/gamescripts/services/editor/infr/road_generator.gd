@tool
extends EditorScript

const ROADS_JSON_PATH_FORMAT = "res://world/%s/jsondata/roads.json"

@export_storage var map_roads_node: Node3D:
	get():
		return EditorUtils.get_open_world().find_child("Roads")

func _run():
	self.clear_editor_tracks()
	var map_name: String = get_map_name()
	if map_name:
		self.spawn_roads_in_world(map_name)

func clear_editor_tracks():
	for child: Node in self.map_roads_node.get_children():
		child.queue_free()

#region Road Path Spawning
func spawn_roads_in_world(map_key: String):
	var file_path := ROADS_JSON_PATH_FORMAT % map_key
	var roads_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	for road_dict: Dictionary in roads_json_arr:
		self.spawn_single_road(road_dict)
		
func spawn_single_road(road_data_dict: Dictionary):
	var road: RoadData = RoadMapper.road_from_data_json(road_data_dict)
	var instanciated: OuterRoad = road.spawn()
	self.map_roads_node.add_child(instanciated, true)
	instanciated.owner = get_scene()
#endregion

func get_map_name():
	var editor_map_name = EditorUtils.get_editor_map_name()
	if ! editor_map_name:
		Loggie.error("Cannot generate editor infrastructure: cannot get open editor map")
		return null
	return editor_map_name
	
