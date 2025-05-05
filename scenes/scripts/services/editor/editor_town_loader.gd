@tool
extends EditorScript
	
const json_path = "res://world/jsondata/towns.json"

func _run():
	create_new_town_labels()
	
func create_new_town_labels():
	var towns: Array[Town] = parse_towns_json()
	for town in towns:
		var editor_label: Label3D = instanciate_editor_label(town)
		# add to "EditorLabels" container
		var parent = get_editor_labels_container()
		parent.add_child(editor_label)
		editor_label.owner = get_scene() # make visible in editor

func parse_towns_json() -> Array[Town]:
	var town_json_str = FileAccess.get_file_as_string(json_path)
	var json_arr = JSON.parse_string(town_json_str) as Array[Dictionary]
	if !json_arr:
		push_warning("Couldnt load Town from \"%s\"" % town_json_str)
		return []
	var town_obj_arr: Array[Town] = []
	for town_values_dict: Dictionary in json_arr:
		town_obj_arr.append(Town.from_json(town_values_dict))
	return town_obj_arr
	
func instanciate_editor_label(_town: Town)-> Label3D:
	var label = Label3D.new()
	label.pixel_size = .33
	label.text = _town.town_name
	label.name = "EditorLabel.Town.%s" % _town.town_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# get town label pos over terrain
	label.position = get_pos_over_terrain(_town.pos_xz)
	return label

func get_editor_labels_container():
	var editor_town_container = get_scene().get_node("World/InEditor/EditorLabels")
	if ! editor_town_container:
		push_error("Cannt find Node \"World/InEditor/EditorTowns\"")
	return editor_town_container
	
func get_terrain() -> Terrain3D:
	var terrain_3d = get_scene().get_node("World/Terrain/WorldTerrain")
	if ! terrain_3d:
		push_error("Cannt find Terrain3D node")
	return terrain_3d
	
func get_pos_over_terrain(pos_xz: Vector2) -> Vector3:
	var terrain: Terrain3D = get_terrain()
	var vec3 = Vector3(pos_xz.x, 0, pos_xz.y)
	var height: float = terrain.data.get_height(vec3)
	return Vector3(vec3.x, height + 15, vec3.z)
