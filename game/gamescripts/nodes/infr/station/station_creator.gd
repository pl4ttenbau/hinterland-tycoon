## Gameplay placement is captured before opening a dialog; no authored geometry is edited.
class_name StationCreator extends Node

const JOIN_RADIUS: float = 50.0
const MIN_STOP_DISTANCE: float = 2.0
var _message: Label

func is_available() -> bool:
	return is_instance_valid(Managers.interchanges) and Managers.interchanges.is_loaded \
		and is_instance_valid(Managers.stations) and Managers.stations.is_loaded \
		and is_instance_valid(Managers.road_stops) and Managers.road_stops.is_loaded

func open_placement_dialog() -> bool:
	if not is_available() or UiState.current_diag != null or not is_instance_valid(GlobalState.player):
		return false
	if GlobalState.player.control.is_in_vehicle():
		return false
	var player: BasicFpsPlayer = GlobalState.player.walking_body
	if not is_instance_valid(player):
		return false
	var placement: Dictionary = placement_at(player.global_position, player.get_rid())
	if placement.is_empty():
		_show_message("Stand on a road or track to create a stop.")
		return false
	var problem: String = placement_error(placement)
	if not problem.is_empty():
		_show_message(problem)
		return false
	var dialog_script: GDScript = load("res://game/gamescripts/ui/dialogs/station_creator/station_creator_dialog.gd")
	get_tree().root.add_child(dialog_script.create(self, placement))
	return true

## Hit the supporting surface, so a nearby road or a bridge cannot steal placement.
func placement_at(position: Vector3, exclude: RID = RID()) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.5, position - Vector3.UP * 2.0, 1)
	if exclude.is_valid():
		query.exclude = [exclude]
	var hit: Dictionary = get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	var surface: Node = hit.get("collider")
	while surface != null and not surface is RoadWay3D and not surface is RailTrack3D:
		surface = surface.get_parent()
	if surface is RoadWay3D:
		return placement_on(surface.road, position)
	if surface is RailTrack3D:
		return placement_on(surface.track, position)
	return {}

func placement_on(infrastructure: AbstractTrack, position: Vector3) -> Dictionary:
	if infrastructure.curve == null or infrastructure.curve.get_point_count() < 2:
		return {}
	var road := infrastructure as RoadData
	var local_position: Vector3 = position - road.start_pos if road != null else position
	var offset: float = infrastructure.curve.get_closest_offset(local_position)
	var center: Vector3 = infrastructure.curve.sample_baked(offset)
	var heading: Vector3 = infrastructure.curve.sample_baked(minf(offset + 0.2, infrastructure.curve.get_baked_length())) - infrastructure.curve.sample_baked(maxf(0.0, offset - 0.2))
	var direction := Enums.RoadStopDirection.ROAD_NODES_INCREASE
	if road != null and (local_position - center).dot(heading.cross(Vector3.UP)) < 0.0:
		direction = Enums.RoadStopDirection.ROAD_NODES_DECREASE
	var nodes: Array = infrastructure.get("nodes")
	var nearest_index: int = 0
	var nearest_distance: float = INF
	for index: int in nodes.size():
		var distance: float = position.distance_squared_to(nodes[index].position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return {"domain": "ROAD" if road != null else "RAIL", "infrastructure_num": infrastructure.num,
		"offset": offset, "node_index": nearest_index, "origin": position,
		"position": center + road.start_pos if road != null else center, "direction": direction}

## One entry per interchange, sorted by its nearest physical stop (across modes).
func nearby_interchanges(position: Vector3) -> Array[InterchangeData]:
	var distances: Dictionary = {}
	var result: Array[InterchangeData] = []
	for interchange: InterchangeData in Managers.interchanges.interchanges:
		var nearest: float = INF
		for stop: AbstractStation in interchange.stops:
			nearest = minf(nearest, position.distance_squared_to(stop.get("position")))
		if nearest <= JOIN_RADIUS * JOIN_RADIUS:
			result.append(interchange)
			distances[interchange.num] = nearest
	result.sort_custom(func(a: InterchangeData, b: InterchangeData) -> bool:
		return a.num < b.num if is_equal_approx(distances[a.num], distances[b.num]) else distances[a.num] < distances[b.num])
	return result

func _infrastructure(placement: Dictionary) -> AbstractTrack:
	if placement.get("domain") == "ROAD" and is_instance_valid(Managers.roads):
		return Managers.roads.storage._by_id.get(placement.get("infrastructure_num"))
	if placement.get("domain") == "RAIL" and is_instance_valid(Managers.rails):
		return Managers.rails.track_storage._by_id.get(placement.get("infrastructure_num"))
	return null

func placement_error(placement: Dictionary) -> String:
	var infrastructure: AbstractTrack = _infrastructure(placement)
	if infrastructure == null or infrastructure.curve == null:
		return "The road or track is no longer available."
	var offset: float = placement.get("offset", -1.0)
	if not is_finite(offset) or offset < 0.0 or offset > infrastructure.curve.get_baked_length():
		return "The road or track has changed. Close this dialog and place again."
	var nodes: Array = infrastructure.get("nodes")
	var node_index: int = placement.get("node_index", -1)
	if node_index < 0 or node_index >= nodes.size():
		return "The road or track has changed. Close this dialog and place again."
	var position: Vector3 = infrastructure.curve.sample_baked(offset)
	if infrastructure is RoadData:
		position += infrastructure.start_pos
	if not position.is_equal_approx(placement.position):
		return "The road or track has changed. Close this dialog and place again."
	for stop: AbstractStation in Managers.interchanges.stops_by_num.values():
		var same_infrastructure: bool = (stop is RoadStationData and infrastructure is RoadData and stop.road_num == infrastructure.num) \
			or (stop is RailStationData and infrastructure is RailTrackData and stop.track_num == infrastructure.num)
		if same_infrastructure and position.distance_squared_to(stop.get("position")) < MIN_STOP_DISTANCE * MIN_STOP_DISTANCE:
			return "A stop already exists at this location."
	return ""

## Validate everything before publishing the new parent or stop.
func create_stop(placement: Dictionary, interchange_num: int, title: String, town_num: int,
		station_type: String, direction: Enums.RoadStopDirection) -> Dictionary:
	if not is_available():
		return {"error": "Station services are no longer available."}
	var problem: String = placement_error(placement)
	if not problem.is_empty():
		return {"error": problem}
	if placement.domain == "RAIL" and station_type not in ["STATION_PASS", "STATION_GOODS"]:
		return {"error": "Choose a passenger or goods stop."}
	if placement.domain == "ROAD" and Enums.RoadStopDirection.find_key(direction) == null:
		return {"error": "Choose the direction of travel."}
	var catalog: InterchangesLoader = Managers.interchanges
	var company := CompanyData.current()
	if company != null:
		problem = company.spending_error(CompanyData.STOP_COST)
		if not problem.is_empty():
			return {"error": problem}
	var nearby: Array[InterchangeData] = nearby_interchanges(placement.origin)
	var interchange: InterchangeData = catalog.by_num.get(interchange_num)
	var created_interchange: bool = interchange_num < 0
	var town: TownData
	if interchange_num >= 0:
		if interchange == null or interchange not in nearby:
			return {"error": "The selected station is no longer within 50 m."}
	else:
		if not nearby.is_empty():
			return {"error": "A station is now nearby. Close this dialog and place again."}
		if title.strip_edges().is_empty():
			return {"error": "Enter a station name."}
		for candidate: TownData in GlobalState.towns:
			if candidate.num == town_num:
				town = candidate
				break
		if town == null:
			return {"error": "Choose a town for the station."}
		interchange = catalog.create_runtime_interchange(title, town)
	var stop: AbstractStation
	if placement.domain == "ROAD":
		var road_stop := RoadStationData.new(catalog.next_stop_num())
		road_stop.road_num = placement.infrastructure_num
		road_stop.node_index = placement.node_index
		road_stop.direction = direction
		road_stop.position = placement.position
		stop = road_stop
	else:
		var rail_stop := RailStationData.new(catalog.next_stop_num())
		rail_stop.track_num = placement.infrastructure_num
		rail_stop.node_index = placement.node_index
		rail_stop.position = placement.position
		rail_stop.station_type = station_type
		stop = rail_stop
	stop.curve_offset = placement.offset
	var error: Error = catalog.register_stop(stop, interchange.num)
	if error != OK:
		if created_interchange:
			catalog.interchanges.erase(interchange)
			catalog.by_num.erase(interchange.num)
			interchange.connections.parent = null
		stop.connections.parent = null
		return {"error": "The stop could not be registered."}
	if company != null:
		company.spend(CompanyData.STOP_COST)
	stop.set("connected_town", interchange.connected_town)
	if interchange.connected_town != null:
		interchange.connected_town.connect_new_station(stop)
	if stop is RoadStationData:
		Managers.road_stops.add_runtime_stop(stop)
	else:
		Managers.stations.add_runtime_stop(stop)
	if is_instance_valid(Managers.world_services):
		Managers.world_services.residence_connector.reassign_all_buildings_to_stations()
		Managers.world_services.industry_connector.has_connected = false
		Managers.world_services.industry_connector.connect_industries()
	return {"stop": stop}

func _show_message(message: String) -> void:
	if not is_instance_valid(_message):
		var canvas := CanvasLayer.new()
		add_child(canvas)
		_message = Label.new()
		_message.position = Vector2(24, 80)
		canvas.add_child(_message)
	_message.text = message
	_message.show()
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(_message):
			_message.hide())
