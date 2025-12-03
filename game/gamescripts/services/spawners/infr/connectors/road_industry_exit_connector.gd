@icon("res://assets/icons/icon_gears_white.png")
class_name RoadIndustryExitConnector extends Node

const MAX_INDUSTRY_SQ_DIST = 400
const LOG_EXIT_FINDING = false

@export var has_roads_loaded: bool = false:
	set(value): 
		has_roads_loaded = value
		self.try_industry_exit_finding()
		
@export var has_industries_loaded: bool = false:
	set(value):
		has_industries_loaded = value
		self.try_industry_exit_finding()

#region Initialization
func _enter_tree() -> void:
	SignalBus.roads_spawned.connect(Callable(self, "_on_roads_spawned"))
	SignalBus.industries_spawned.connect(Callable(self, "_on_industries_spawned"))
#endregion

func try_industry_exit_finding():
	if !self.has_industries_loaded || !self.has_roads_loaded: return
	var found_road_exits: int = 0
	for industry3d: OuterIndustry in GlobalState.ind_bld_containers:
		var closest_road_node = self.find_closest_road_node(industry3d.industry)
		if closest_road_node:
			industry3d.industry.road_exit = closest_road_node
			found_road_exits += 1
	Loggie.info("Found %d road exits for %d industries" % [found_road_exits, GlobalState.ind_bld_containers.size()])
		
#region Find Close
func find_close_roads(industry: IndustryData) -> Array[RoadData]:
	var close_roads: Array[RoadData] = []
	for road: RoadData in GlobalState.roads:
		var road_center: Vector3 = road.center
		var sq_dist_to_center := industry.pos.distance_to(road_center)
		if sq_dist_to_center <= MAX_INDUSTRY_SQ_DIST:
			close_roads.append(road)
	return close_roads
	
func find_closest_road_node(industry: IndustryData) -> RoadNode:
	var closest_node: RoadNode
	var closest_node_dist: float = 99999
	var pos: Vector3 = industry.pos
	for road: RoadData in self.find_close_roads(industry):
		for road_node: RoadNode in road.nodes:
			var sq_dist: float = pos.distance_to(road_node.position)
			if sq_dist > 30: continue
			if sq_dist <= closest_node_dist:
				closest_node_dist = sq_dist
				closest_node = road_node
	if LOG_EXIT_FINDING:
		if closest_node: Loggie.info("Found road exit for industry \"%s\"" % industry.ind_name)
		else: Loggie.warn("Cant find exit for industry \"%s\"" % industry.ind_name)
	return closest_node
#endregion

#region Callbacks
func _on_roads_spawned():
	self.has_roads_loaded = true
	
func _on_industries_spawned():
	self.has_industries_loaded = true
#endregion
