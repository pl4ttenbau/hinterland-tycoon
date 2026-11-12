@icon("res://assets/icons/icon_industry_white.png")
class_name IndustrySpawner extends Node

const INDUSTRIES_PATH_TEMPLATE = "res://world/%s/jsondata/industries.json"

@export_storage var ind_placeholder_parent: WorldIndustries
@export var storage: IndustryStore = IndustryStore.new()

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
		var industry3d := Industry3D.of(ind_obj)
		if industry3d: # register
			self.add_child(industry3d)
			self.storage.add_container(industry3d)
	SignalBus.industries_spawned.emit()

## The caller owns the off-tree view until placement succeeds.
func place_runtime_industry(view: Industry3D, recipe: IndustryType, position: Vector3) -> void:
	var industry := IndustryData.new(recipe.key, position, recipe)
	view.industry = industry
	add_child(view)
	view.global_position = position
	storage.add_container(view)
	view.tree_exiting.connect(_remove_runtime_industry.bind(view), CONNECT_ONE_SHOT)
	StationIndustriesConnector.connect_industry(industry)
	if is_instance_valid(Managers.world_services):
		industry.road_exit = Managers.world_services.road_exit_connector.find_closest_road_node(industry)

func _remove_runtime_industry(view: Industry3D) -> void:
	# Break the interchange's back-reference before the view and its data go away.
	var connection: StationIndustryConnection = view.industry.station_connection
	if connection != null and connection.interchange != null:
		connection.interchange.connections.industries.erase(connection)
		view.industry.station_connection = null
	storage.remove_runtime_industry(view)

#region Getters
func get_map_industry_container() -> WorldIndustries:
	if self.ind_placeholder_parent != null: return self.ind_placeholder_parent
	var map_container: WorldMapScene = GlobalState.world_container
	if ! map_container:
		Loggie.error("Cannot collect town buildings: Terrain data not loaded")
		return null
	self.ind_placeholder_parent = map_container.find_child("Industries")
	return self.ind_placeholder_parent
#endregion

#region Callbacks
func _on_terrain_loaded(_terrain_container: WorldMapScene):
	self.spawn_industries()
	
#endregion
