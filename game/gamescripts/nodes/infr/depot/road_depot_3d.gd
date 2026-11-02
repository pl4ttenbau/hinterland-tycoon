@icon("res://assets/icons/nodes_3d/icon_depot.svg")
class_name RoadDepot3D extends GameEntity3D

const SCENE_PATH = "uid://dgluh21b1xnjh"

@export_storage var road: RoadData:
	get(): return RoadData.get_by_num(self.depot.road_num)

@export_storage var depot: RoadDepotData:
	get(): return self.entity as RoadDepotData
	set(value): self.entity = value

#region Initialization
static func of(depot_obj: RoadDepotData) -> RoadDepot3D:
	var prefab: PackedScene = preload(SCENE_PATH)
	var instanciated_container: RoadDepot3D = prefab.instantiate()
	instanciated_container.depot = depot_obj
	instanciated_container.position = instanciated_container.get_pos_from_road()
	instanciated_container.set_meta("depot", depot_obj)
	return instanciated_container
	
## Face inward from either endpoint. The origin is also a valid target position.
func adjust_rotation() -> void:
	if road == null or road.nodes.size() < 2:
		return
	var target_index: int = 1 if depot.road_pos == "START" else road.nodes.size() - 2
	var target_pos: Vector3 = road.nodes[target_index].position
	if not global_position.is_equal_approx(target_pos):
		look_at(target_pos)
#endregion
	
#region Depot Track Node Getters
func get_pos_from_road() -> Vector3:
	var road_node := self.depot.get_depot_road_node()
	if !road_node:
		Loggie.error("Cannot get depot position: neither at track START nor END")
		return Vector3.ZERO
	return road_node.position
#endregion
