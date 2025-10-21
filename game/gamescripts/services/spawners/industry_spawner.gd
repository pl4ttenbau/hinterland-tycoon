@icon("res://assets/icons/icon_industry_white.png")
class_name IndustrySpawner extends Node

const INDUSTRIES_PATH_TEMPLATE = "res://world/%s/jsondata/industries.json"

@export_storage var ind_placeholder_parent: WorldIndustries

func _enter_tree() -> void:
	Managers.industries = self
	SignalBus.map_spawned.connect(Callable(self, "_on_terrain_loaded"))
	SignalBus.all_types_initialized.connect(Callable(self, "_on_all_types_loaded"))
	
func load_industries_from_json():
	var industry_json_path := INDUSTRIES_PATH_TEMPLATE % GlobalState.selected_map_name
	var json_str: String = FileAccess.get_file_as_string(industry_json_path)
	for ind_dict: Dictionary in JSON.parse_string(json_str):
		IndustryData.from_dict(ind_dict)
		
func load_industries_from_map():
	for child_node in self.get_map_industry_container().get_children():
		if ! child_node is IndustryPlaceholder: continue
		var ind_placeholder: IndustryPlaceholder = child_node as IndustryPlaceholder
		IndustryData.from_placeholder(ind_placeholder) # will autoregister
	
func spawn_industries():
	Loggie.info("ready to spawn industries")
	self.load_industries_from_map()
	for ind_obj: IndustryData in GlobalState.industries:
		if ! ind_obj.ind_type:
			Loggie.error("cannot spawn industry! type \"%s\" unknown" % ind_obj.ind_type)
			continue
		var scene_path := ind_obj.ind_type.get_mesh_path()
		var instanciated: OuterIndustry = load(scene_path).instantiate()
		instanciated.industry = ind_obj
		self.add_child(instanciated)
	SignalBus.industries_spawned.emit()
		
#region Getters
func get_map_industry_container() -> WorldIndustries:
	if self.ind_placeholder_parent != null: return self.ind_placeholder_parent
	var map_container: TerrainContainer = GlobalState.world_container
	if ! map_container:
		Loggie.error("Cannot collect town buildings: Terrain data not loaded")
		return null
	self.ind_placeholder_parent = map_container.find_child("Industries")
	return self.ind_placeholder_parent
#endregion

#region Callbacks
func _on_terrain_loaded(_terrain_container: TerrainContainer):
	self.spawn_industries()
	
func _on_all_types_loaded():
	pass
	# self.load_industries_from_map()
#endregion
