@icon("res://assets/icons/icon_depot_white.png")
class_name DepotLoader extends Node

const MAP_DEPOTS_FILEPATH_FORMAT := "res://world/%s/jsondata/vehicles_depots.json"

@export var depots: Array[RailDepotData] = []
@export var containers: Array[OuterDepot] = []

func _enter_tree() -> void:
	Managers.depots = self
	SignalBus.rails_loaded.connect(Callable(self, "_on_rails_loaded"))
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_spawned"))
	
#region Loading
func load_depots():
	Loggie.info("Loading depots..")
	var full_json_path := MAP_DEPOTS_FILEPATH_FORMAT % GlobalState.loaded_map_name
	var json_str: String = FileAccess.get_file_as_string(full_json_path)
	for depot_dict in JSON.parse_string(json_str).depots:
		self.depots.append(RailDepotData.of_json(depot_dict))
	GlobalState.depots = self.depots
#endregion

#region Spawning
## Station objects are created with the rail tracks, but instanciated one by one here
func spawn_depots():
	Loggie.info("Spawning depots..")
	for depot_obj: RailDepotData in self.depots:
		var container: OuterDepot = spawn_depot(depot_obj)
		self.containers.append(container)
	
func spawn_depot(depot_obj: RailDepotData) -> OuterDepot:
	depot_obj.num = RailDepotData.next_depot_num()
	var container: OuterDepot = depot_obj.spawn()
	self.add_child(container, true)
	container.adjust_rotation()
	return container
#endregion

func _on_rails_loaded(_rails: Array[RailTrackData]) -> void:
	load_depots()
	
func _on_rails_spawned(_rails: Array[OuterRailTrack]) -> void:
	spawn_depots()
