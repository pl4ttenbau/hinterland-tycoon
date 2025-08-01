@icon("res://assets/icons/icon_depot.png")
class_name OuterDepot extends HideableObject

const SCENE_PATH = "res://assets/meshes/infr/rail/rail_depot/rail_depot.tscn"

@export_storage var track: RailTrackData:
	get(): return RailTrackData.get_by_num(self.depot.track_num)

@export_storage var depot: RailDepotData:
	get(): return self.entity as RailDepotData
	set(value): self.entity = value
	
static func of(depot_obj: RailDepotData) -> OuterDepot:
	var prefab: PackedScene = preload(SCENE_PATH)
	var instanciated_container: OuterDepot = prefab.instantiate()
	instanciated_container.depot = depot_obj
	instanciated_container.position = instanciated_container.get_pos_from_rail()
	instanciated_container.set_meta("depot", depot_obj)
	return instanciated_container
	
func adjust_rotation():
	var target_pos: Vector3 = Vector3.ZERO
	if self.depot.track_pos == "START":
		target_pos = self.track.nodes[1].position
	else:
		var rot_target_node_index = self.track.get_end_node().index -1
		target_pos = self.track.get_rail_node(rot_target_node_index).position
	if target_pos != Vector3.ZERO:
		self.look_at(target_pos)
	
#region Depot Track Node Getters
func get_pos_from_rail() -> Vector3:
	var rail_node := self.depot.get_depot_rail_node()
	if !rail_node:
		Loggie.error("Cannot get depot position: neither at track START nor END")
		return Vector3.ZERO
	return rail_node.position
#endregion
