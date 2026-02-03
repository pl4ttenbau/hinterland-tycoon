@tool
@icon("res://assets/icons/icon_gears_white.png")
class_name WorldTracksGenerator extends BaseInfrGenerator

const RAIL_COLOR = Color.BLACK
const TRACKS_JSON_PATH_FORMAT = "res://world/%s/jsondata/tracks.json"

func spawn_track_paths():
	var file_path := TRACKS_JSON_PATH_FORMAT % self.get_map_name()
	var rails_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	for track_dict: Dictionary in rails_json_arr:
		self.spawn_single_track_line(track_dict)
	
func spawn_single_track_line(track_data_dict: Dictionary) -> EditorInfrLine3D:
	var line3d := RailMapper.editor_line_from_data(track_data_dict)
	line3d.create_curve_from_dict(track_data_dict, true)
	# add as child & assign to editor scene
	self.get_infr_container().add_rail(line3d, EditorInterface.get_edited_scene_root())
	return line3d
