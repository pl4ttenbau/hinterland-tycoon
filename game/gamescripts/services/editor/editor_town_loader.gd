@tool
extends EditorScript
	
const JSON_PATH = "res://world/demmin/jsondata/towns.json"

func _run():
	self.clear_children()
	self.create_new_town_labels()
	
func create_new_town_labels():
	var towns: Array[TownData] = parse_towns_json()
	for town in towns:
		var editor_label: Label3D = instanciate_editor_label(town)
		# add to "EditorLabels" container
		var parent = get_editor_labels_container()
		parent.add_child(editor_label)
		editor_label.owner = get_scene() # make visible in editor

func parse_towns_json() -> Array[TownData]:
	var town_json_str = FileAccess.get_file_as_string(JSON_PATH)
	var json_arr = JSON.parse_string(town_json_str) as Array[Dictionary]
	if !json_arr:
		push_warning("Couldnt load Town from \"%s\"" % town_json_str)
		return []
	var town_obj_arr: Array[TownData] = []
	for town_values_dict: Dictionary in json_arr:
		town_obj_arr.append(TownData.from_json(town_values_dict))
	return town_obj_arr
	
func instanciate_editor_label(_town: TownData)-> Label3D:
	var label = Label3D.new()
	label.pixel_size = .33
	label.text = _town.town_name
	label.name = "EditorLabel.Town.%s" % _town.town_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# get town label pos over terrain
	label.position = get_pos_over_terrain(_town.pos_xz)
	return label
	
func clear_children():
	for child: Node in self.parent.get_children():
		child.queue_free()
	
func get_pos_over_terrain(pos_xz: Vector2) -> Vector3:
	var vec3 = Vector3(pos_xz.x, 0, pos_xz.y)
	var height: float = get_terrain().data.get_height(vec3)
	return Vector3(vec3.x, height + 15, vec3.z)

#region Node Getters
func get_terrain() -> Terrain3D:
	var terrain_3d = get_scene().find_child("WorldTerrain", true)
	if ! terrain_3d:
		push_error("Cannt find Terrain3D node")
		return
	return terrain_3d
	
func get_editor_labels_container():
	var editor_town_container = get_scene().find_child("EditorLabels", true)
	if ! editor_town_container:
		push_error("Cannt find Node \"World/InEditor/EditorTowns\"")
	return editor_town_container
#endregion
