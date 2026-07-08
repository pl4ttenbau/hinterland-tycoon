@tool
@icon("res://assets/icons/icon_town.png")
class_name Town3D extends GameEntity3D

signal town_changed(_town: TownData)

@export var town: TownData:
	set(value):
		if ! value:
			return
		town = value
		self.name = value.to_string()
		set_label_text(value.town_name)
		self.town.town_name_changed.connect(Callable(self, "_on_town_name_changed"))
		self.town_changed.emit(value)
	get(): return town
	
@export_tool_button("Position", "Callable")
var position_action = do_position

@export_tool_button("From WorldCursor", "Callable")
var copy_pos_from_cursor_action = do_copy_cursor_pos
	
func set_label_text(new_name: String):
	if new_name && $SubViewport/Town3DSign:
		self.name = "Town3D_%s" % new_name
		$SubViewport/Town3DSign.town_name = new_name

func _on_town_name_changed(town_name: String):
	self.set_label_text(town_name)
	
#region Editor Auto-Positioning (disabled)
func do_position() -> void:
	var pos_xz = self.town.pos_xz
	self.global_position = self.get_pos_on_terrain(pos_xz)

func do_copy_cursor_pos() -> void:
	pass

func get_pos_on_terrain(pos_xz: Vector2) -> Vector3:
	var xz_vec3 = Vector3(pos_xz.x, 0, pos_xz.y)
	var terrain_y = self.get_editor_terrain().data.get_height(xz_vec3)
	return Vector3(xz_vec3.x, terrain_y, xz_vec3.z)
	
func get_editor_terrain() -> Terrain3D:
	var edited_scene_root: Node = EditorInterface.get_edited_scene_root()
	var terrain_3d = edited_scene_root.find_child("WorldTerrain", true)
	if ! terrain_3d: 
		Loggie.error("Cannt find Terrain3D node")
		return null
	return terrain_3d
#endregion
