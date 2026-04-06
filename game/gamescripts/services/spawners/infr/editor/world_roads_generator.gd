@tool
@icon("res://assets/icons/icon_gears_white.png")
class_name WorldRoadsGenerator extends BaseInfrGenerator

const ROADS_JSON_PATH_FORMAT = "res://world/%s/jsondata/roads.json"
const ROAD_COLOR = Color.DARK_ORANGE

func spawn_road_paths():
	var file_path := ROADS_JSON_PATH_FORMAT % self.get_map_name()
	var roads_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	for road_dict: Dictionary in roads_json_arr:
		self.spawn_road_line_3d(road_dict)
		
func spawn_road_line_3d(road_data_dict: Dictionary) -> LinePath3D:
	var line3d := RoadMapper.editor_line_from_data(road_data_dict)
	line3d.create_curve_from_dict(road_data_dict)
	# add as child & assign to editor scene
	self.get_roads_container().add_road(line3d)
	return line3d

func get_roads_container() -> GeneratedRoadWays:
	for child: Node in self.get_infr_container().get_children():
		if child is GeneratedRoadWays:
			return child as GeneratedRoadWays
	return null
