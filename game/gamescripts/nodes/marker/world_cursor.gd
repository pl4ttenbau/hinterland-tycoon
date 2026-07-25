@tool
@icon("res://assets/icons/icon_mouse_3d.png")
class_name WorldCursor3D extends Marker3D

@export_tool_button("Put On Ground")
var put_on_ground = Callable(self, "_do_put_on_ground")

@export_tool_button("Copy Pos As Json")
var copy_pos_as_json = Callable(self, "_do_copy_pos_as_json")

@export_group("GPS0", "gps_")

@export var gps_coords: String

@export_tool_button("From GPS Coords", "Callable")
var gps_apply_fromcoords = do_apply_gps_coords_pos

#region Tool Actions
func _do_put_on_ground():
	var height: float = EditorUtils.get_y_at_pos(self.global_position)
	self.global_position.y = height

func _do_copy_pos_as_json():
	var abs_pos: Vector3 = self.global_position
	var abs_pos_float_arr: Array[float] = [
		snapped(abs_pos.x, 0.01), 
		snapped(abs_pos.y, 0.01), 
		snapped(abs_pos.z, 0.01)
	]
	var abs_pos_arr_str: String = JSON.stringify(abs_pos_float_arr)
	# copy to clipboard
	Loggie.info("WorldCursor Pos: %s" % abs_pos_arr_str)
	DisplayServer.clipboard_set(abs_pos_arr_str)
#endregion

#region Editor Auto-Positioning (disabled)
func do_apply_gps_coords_pos() -> void:
	if !self.gps_coords || self.gps_coords.is_empty():
		Loggie.warn("Cannot place at GPS coords: empty string")
		return
	var gps_coords_arr: Array[float] = WorldUtils.gps_coords_str_to_float_arr(self.gps_coords)
	# get map size, pos & longLat dto
	var size_and_pos_dto: MapSizeAndPosData = self.get_map_size_pos_dto_in_editor()
	# apply to get XY pos on map
	var world_xy: Vector2i = WorldUtils.gps_coords_to_map_pos(gps_coords_arr, size_and_pos_dto)
	Loggie.info("Position on map: %s" % world_xy)
	# find y pos and place accordingly
	self.global_position = WorldUtils.pos_on_map(world_xy)

func get_map_size_pos_dto_in_editor() -> MapSizeAndPosData:
	var open_map_key: String = EditorUtils.get_editor_map_name()
	var map_data: MapData = MapData.parse(open_map_key)
	if !map_data || !map_data.size_and_pos:
		Loggie.error("Cannot load SizeAndPosDto for map \"%s\"" % open_map_key)
	return map_data.size_and_pos

func get_editor_terrain() -> Terrain3D:
	var edited_scene_root: Node = EditorInterface.get_edited_scene_root()
	var terrain_3d = edited_scene_root.find_child("WorldTerrain", true)
	if ! terrain_3d: 
		Loggie.error("Cannt find Terrain3D node")
		return null
	return terrain_3d
#endregion
