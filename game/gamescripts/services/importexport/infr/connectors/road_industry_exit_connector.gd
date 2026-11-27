@icon("res://assets/icons/icon_gears_white.png")
class_name RoadIndustryExitConnector extends Node

# Constants
## How far a road node may be from an industry to become its road exit.
const MAX_IND_NODE_DIST = 60
const LOG_EXIT_FINDING = false

# Loading FLags
@export var has_roads_loaded: bool = false
@export var has_industries_loaded: bool = false

#region Initialization
#endregion

func try_industry_exit_finding():
	if !self.has_industries_loaded || !self.has_roads_loaded: return
	var found_road_exits: int = 0
	for industry3d: Industry3D in GlobalState.ind_bld_containers:
		var closest_road_node = self.find_closest_road_node(industry3d.industry)
		industry3d.industry.road_exit = closest_road_node
		if closest_road_node:
			found_road_exits += 1
	Loggie.info("Found %d road exits for %d industries" % [found_road_exits, GlobalState.ind_bld_containers.size()])
		
#region Find Close
func find_close_roads(industry: IndustryData) -> Array[RoadData]:
	var close_roads: Array[RoadData] = []
	if Managers.roads == null:
		return close_roads
	# Only roads whose bounds come within node distance can have a node close enough: a single box test
	# skips all other roads before their nodes are looked at.
	for road: RoadData in Managers.roads.storage.get_all():
		if road.is_near(industry.pos, MAX_IND_NODE_DIST):
			close_roads.append(road)
	return close_roads
	
func find_closest_road_node(industry: IndustryData) -> RoadNode:
	var closest_node: RoadNode
	var closest_node_dist: float = 99999
	var pos: Vector3 = industry.pos
	for road: RoadData in self.find_close_roads(industry):
		for road_node: RoadNode in road.nodes:
			var dist: float = pos.distance_to(road_node.position)
			if dist > MAX_IND_NODE_DIST: continue
			if dist <= closest_node_dist:
				closest_node_dist = dist
				closest_node = road_node
	if LOG_EXIT_FINDING:
		if closest_node: Loggie.info("Found road exit for industry \"%s\"" % industry.ind_name)
		else: Loggie.warn("Cant find exit for industry \"%s\"" % industry.ind_name)
	return closest_node
#endregion

#region Callbacks
func _on_roads_spawned():
	self.has_roads_loaded = true
	self.try_industry_exit_finding()
	
func _on_industries_spawned():
	self.has_industries_loaded = true
	self.try_industry_exit_finding()	
#endregion
