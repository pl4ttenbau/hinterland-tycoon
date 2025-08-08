@icon("res://assets/icons/icon_station.png")
class_name OuterRailStation extends HideableObject

const STATION_SCENE_PATH = "res://scenes/subscenes/infr/outer_rail_station.tscn"

@export_storage var station_obj: RailStationData:
	get(): return self.entity as RailStationData
		

func _enter_tree() -> void:
	self.station_obj.resource_change.connect(Callable(self, "_on_resource_change"))
	self._hide_building_when_set()

static func of(_station_obj: RailStationData) -> OuterRailStation:
	var prefab: PackedScene = preload(STATION_SCENE_PATH)
	var instanciated_container: OuterRailStation = prefab.instantiate()
	instanciated_container.position = _station_obj.position
	instanciated_container.entity = _station_obj
	instanciated_container.set_meta("station", _station_obj)
	return instanciated_container
	
func _hide_building_when_set():
	if self.station_obj.hide_building == true:
		$RailStationMesh.visible = false
	
func rotate_to_prev_node():
	var station_node_index: int = self.entity.parent_node.index
	var prev_node = self.get_parent_track_node_by_index(station_node_index -1)
	self.look_at(prev_node.position)
	
func get_parent_track_node_by_index(_i: int) -> RailNodeData:
	var track: RailTrackData = self.entity.parent_node.parent_track
	return track.get_rail_node(_i)
	
func _on_resource_change():
	$StationLabel.text = str(self.station_obj.resources.size())
