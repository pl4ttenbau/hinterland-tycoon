@tool
@icon("res://assets/icons/icon_town.png")
class_name Town3D extends GameEntity3D

signal town_changed(_town: TownData)

@export var town: TownData:
	set(value):
		if ! value:
			return
		town = value
		
		self.town_changed.emit(value)
	get(): return town

@export_group("Positioning", "pos_")

@export_tool_button("From WorldCursor", "Callable")
var pos_copy_from_cursor_action = do_copy_cursor_pos

@export var pos_gps_coords: String

@export_tool_button("From GPS Coords", "Callable")
var pos_apply_from_gps_coords = do_apply_gps_coords_pos

#region Initialization
func _init() -> void:
	var town_changed_callable: Callable = Callable(self, "_on_town_data_changed")
	if !self.town_changed.is_connected(town_changed_callable):
		self.town_changed.connect(town_changed_callable)

func set_label_text(new_name: String):
	if new_name && $SubViewport/Town3DSign:
		self.name = "Town3D_%s" % new_name
		$SubViewport/Town3DSign.town_name = new_name
#endregion

#region Callbacks
func _on_town_data_changed(town_data: TownData):
	self.name = town_data.to_string()
	set_label_text(town_data.town_name)
	self.town.town_name_changed.connect(Callable(self, "_on_town_name_changed"))

func _on_town_name_changed(town_name: String):
	self.set_label_text(town_name)
#endregion

#region Editor Auto-Positioning (disabled)
func do_copy_cursor_pos() -> void:
	pass

func do_apply_gps_coords_pos() -> void:
	if !self.pos_gps_coords || self.pos_gps_coords.is_empty():
		Loggie.warn("Cannot place at GPS coords: empty string")
		return
	var gps_coords_arr: Array[float] = WorldUtils.gps_coords_str_to_float_arr(self.pos_gps_coords)
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
