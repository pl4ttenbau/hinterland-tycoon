@icon("res://assets/icons/icon_station.png")
class_name OuterRailStation extends HideableObject

const STATION_SCENE_PATH = "res://scenes/subscenes/infr/outer_rail_station.tscn"
const NINETY_DEG_IN_RAD = 1.57

@export_storage var node_station: RailNodeStationData:
	get(): return self.entity as RailNodeStationData
	set(value): 
		self.entity = value
		self.position = value.position
		self._update_station_name()

func _enter_tree() -> void:
	if self.node_station.parent_station:
		var parent_station: RailStationData = self.node_station.parent_station
		parent_station.resource_change.connect(Callable(self, "_on_resource_change"))
	# hide building on flag == true TODO fix
	#if self.node_station.hide_building == true:
	#	$RailStationMesh.visible = false

static func of(_node_station: RailNodeStationData) -> OuterRailStation:
	var prefab: PackedScene = preload(STATION_SCENE_PATH)
	var instanciated_container: OuterRailStation = prefab.instantiate()
	instanciated_container.node_station = _node_station
	return instanciated_container
	
func adjust_rotation_from_track():
	var track_node: RailNodeData = self.node_station.parent_node
	var prev_node = self.get_parent_track_node_by_index(track_node.index -1)
	self.look_at(prev_node.position)
	self.rotate_y(NINETY_DEG_IN_RAD)
	
func get_parent_track_node_by_index(_i: int) -> RailNodeData:
	var track: RailTrackData = self.node_station.parent_node.parent_track
	return track.get_rail_node(_i)
	
func _on_resource_change():
	var passengers_amount: int = self.station_obj.storage.get_amount("PASSENGERS")
	%ResourceAmountLabel.text = str(passengers_amount)
	
func _update_station_name():
	if self.node_station && self.node_station.parent_station:
		%StationNameLabel.text = self.node_station.parent_station.town_name
	
func _to_string() -> String:
	return "OuterStation-%s@%s" % [self.station_name, self.town_name]
