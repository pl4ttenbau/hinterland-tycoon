@icon("res://assets/icons/icon_industry_white.png")
class_name IndustrySpawner extends Node

const MAP_INDUSTRIES_FILEPATH = "res://world/demmin/jsondata/industries.json"
const IND_SCENE_PATH = "res://assets/meshes/industry/generic_small/generic_small.tscn"

func _enter_tree() -> void:
	SignalBus.terrain_initialized.connect(Callable(self, "_on_terrain_loaded"))
	SignalBus.all_types_initialized.connect(Callable(self, "_on_all_types_loaded"))
	
func load_industries():
	var json_str: String = FileAccess.get_file_as_string(MAP_INDUSTRIES_FILEPATH)
	for ind_dict: Dictionary in JSON.parse_string(json_str):
		Industry.from_dict(ind_dict)
	
func spawn_industries():
	Loggie.info("ready to spawn industries")
	self.load_industries()
	for ind_obj: Industry in GlobalState.industries:
		var instanciated: OuterIndustry = load(IND_SCENE_PATH).instantiate()
		instanciated.entity = ind_obj
		instanciated.position = ind_obj.pos
		self.add_child(instanciated)

# == LISTENERS == 
func _on_terrain_loaded(terrain_container: TerrainContainer):
	self.spawn_industries()
	
func _on_all_types_loaded():
	self.load_industries()
