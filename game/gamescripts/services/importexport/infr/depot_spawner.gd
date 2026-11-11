@icon("res://assets/icons/icon_depot_white.png")
class_name DepotLoader extends Node

const MAP_DEPOTS_FILEPATH_FORMAT := "res://world/%s/jsondata/vehicles_depots.json"

@export var rail_depots: Array[RailDepotData] = []
@export var rail_containers: Array[RailDepot3D] = []
@export var road_depots: Array[RoadDepotData] = []
@export var road_containers: Array[RoadDepot3D] = []

#region Loading
func load_rail_depots():
	Loggie.info("Loading rail depots..")
	var full_json_path := MAP_DEPOTS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var json_str: String = FileAccess.get_file_as_string(full_json_path)
	var depot_json_dict: Dictionary = JSON.parse_string(json_str)
	if !depot_json_dict.has("railDepots"):
		Loggie.warn("Loading map has no defined rail depots")
		return
	for depot_dict in depot_json_dict.railDepots:
		self.rail_depots.append(
			RailDepotData.of_json(depot_dict)
		)
	GlobalState.rail_depots = self.rail_depots

func load_road_depots():
	Loggie.info("Loading road depots..")
	var full_json_path := MAP_DEPOTS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var json_str: String = FileAccess.get_file_as_string(full_json_path)
	var depot_json_dict: Dictionary = JSON.parse_string(json_str)
	if !depot_json_dict.has("roadDepots"):
		Loggie.warn("Loading map has no defined road depots")
		return
	for depot_dict in depot_json_dict.roadDepots:
		self.road_depots.append(
			RoadDepotData.of_json(depot_dict)
		)
	GlobalState.road_depots = self.road_depots
#endregion

#region Spawning: Rail Depots
## Station objects are created with the rail tracks, but instanciated one by one here
func spawn_rail_depots():
	Loggie.info("Spawning depots..")
	for depot_obj: RailDepotData in self.rail_depots:
		var rail_depot_3d: RailDepot3D = self.spawn_single_rail_depot(depot_obj)
		self.rail_containers.append(rail_depot_3d)

func spawn_single_rail_depot(depot_obj: RailDepotData) -> RailDepot3D:
	depot_obj.num = RailDepotData.next_depot_num()
	var rail_depot_3d: RailDepot3D = depot_obj.spawn()
	self.add_child(rail_depot_3d, true)
	rail_depot_3d.adjust_rotation()
	return rail_depot_3d
#endregion

#region Spawning: Road Depots
func spawn_road_depots():
	Loggie.info("Spawning depots..")
	for depot_obj: RoadDepotData in self.road_depots:
		var road_depot_3d: RoadDepot3D = self.spawn_single_road_depot(depot_obj)
		if road_depot_3d != null:
			self.road_containers.append(road_depot_3d)

func spawn_single_road_depot(depot_obj: RoadDepotData) -> RoadDepot3D:
	var road: RoadWay3D = Managers.roads.storage.get_container_by_num(depot_obj.road_num)
	if road == null:
		return null
	# Preserve the authored ID used by lookup and click references.
	var road_depot_3d: RoadDepot3D = depot_obj.spawn()
	self.add_child(road_depot_3d, true)
	if not road_depot_3d.align_to_road(road.get_path_3d()):
		Loggie.warn("Cannot align road depot %d to road %d" % [depot_obj.num, depot_obj.road_num])
		road_depot_3d.free()
		return null
	return road_depot_3d
#endregion

#region Callbacks
# RAIL
func _on_rails_loaded(_rails: Array[RailTrackData]) -> void:
	self.load_rail_depots()

func _on_rails_spawned(_rails: Array[RailTrack3D]) -> void:
	self.spawn_rail_depots()

# ROAD
func _on_roads_loaded(_roads: Array[RoadData]) -> void:
	load_road_depots()

func _on_roads_spawned() -> void:
	spawn_road_depots()
