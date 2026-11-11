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
	instanciated_container.set_meta("depot", depot_obj)
	return instanciated_container
#endregion

## Place the garage entrance at the live road endpoint with its +Z axis facing the road.
func align_to_road(path: Path3D) -> bool:
	if path == null or path.curve == null or depot.road_pos not in ["START", "END"]:
		return false
	var length: float = path.curve.get_baked_length()
	if is_zero_approx(length):
		return false
	var from_start: bool = depot.road_pos == "START"
	var sample_distance: float = minf(0.5, length)
	var endpoint: Vector3 = path.to_global(path.curve.sample_baked(0.0 if from_start else length))
	var along_road: Vector3 = path.to_global(path.curve.sample_baked(sample_distance if from_start else length - sample_distance))
	var heading: Vector3 = along_road - endpoint
	heading.y = 0.0
	if heading.is_zero_approx():
		return false
	var facing: Basis = Basis.looking_at(heading, Vector3.UP, true)
	var entrance: Marker3D = $RoadEntrance
	global_transform = Transform3D(facing, endpoint - facing * entrance.position)
	return true
