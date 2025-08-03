@icon("res://assets/icons/icon_industry_white.png")
class_name IndustrySpawner extends Node

const INDUSTRIES_PATH_TEMPLATE = "res://world/%s/jsondata/industries.json"

func _enter_tree() -> void:
	Managers.industries = self
	SignalBus.map_spawned.connect(Callable(self, "_on_terrain_loaded"))
	SignalBus.all_types_initialized.connect(Callable(self, "_on_all_types_loaded"))
	
func load_industries():
	var industry_json_path := INDUSTRIES_PATH_TEMPLATE % GlobalState.loaded_map_name
	var json_str: String = FileAccess.get_file_as_string(industry_json_path)
	for ind_dict: Dictionary in JSON.parse_string(json_str):
		IndustryData.from_dict(ind_dict)
	
func spawn_industries():
	Loggie.info("ready to spawn industries")
	self.load_industries()
	for ind_obj: IndustryData in GlobalState.industries:
		var scene_path := ind_obj.ind_type.get_mesh_path()
		var instanciated: OuterIndustry = load(scene_path).instantiate()
		instanciated.entity = ind_obj
		instanciated.position = ind_obj.pos
		self.add_child(instanciated)

# == LISTENERS == 
func _on_terrain_loaded(_terrain_container: TerrainContainer):
	self.spawn_industries()
	
func _on_all_types_loaded():
	self.load_industries()
