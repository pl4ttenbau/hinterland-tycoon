## Gameplay placement is captured before opening a dialog; no authored geometry is edited.
class_name StationCreator extends Node

const JOIN_RADIUS: float = 50.0
const MIN_STOP_DISTANCE: float = 2.0
var _message: Label
var _rail_buildings: Dictionary[String, StationBuildingCatalog] = {}

func is_available() -> bool:
	return is_instance_valid(Managers.interchanges) and Managers.interchanges.is_loaded \
		and is_instance_valid(Managers.stations) and Managers.stations.is_loaded \
		and is_instance_valid(Managers.road_stops) and Managers.road_stops.is_loaded

func action_title(player: BasicFpsPlayer) -> String:
	if is_instance_valid(player) and player.is_inside_tree():
		var placement: Dictionary = placement_at(player.global_position, player.get_rid())
		if placement.get("domain") == "RAIL":
			return "Build platform"
	return "Create stop"


func open_placement_dialog() -> bool:
	if not is_available() or UiState.current_diag != null or not is_instance_valid(GlobalState.player):
		return false
	if GlobalState.player.control.is_in_vehicle():
		return false
	var player: BasicFpsPlayer = GlobalState.player.walking_body
	if not is_instance_valid(player):
		return false
	# The modal takes over input. Capture the view now so the two road-side
	# choices keep their meaning for the entire confirmation.
	var camera: Camera3D = GlobalState.player.control.active_camera()
	var view_forward: Vector3 = -camera.global_basis.z if is_instance_valid(camera) else Vector3.ZERO
	var placement: Dictionary = placement_at(player.global_position, player.get_rid(), view_forward)
	if placement.is_empty():
		_show_message("Stand on a road or track to create a stop.")
		return false
	var problem: String = placement_error(placement)
	if not problem.is_empty():
		_show_message(problem)
		return false
	var dialog: StationCreatorDialog = StationCreatorDialog.create(self, placement)
	if dialog == null:
		_show_message("The stop preview is unavailable.")
		return false
	add_child(dialog)
	return true

## Instance the shelter art only. The actual stop owns collision, signs and inventory.
func make_road_preview(placement: Dictionary) -> Node3D:
	var road := _infrastructure(placement) as RoadData
	if road == null:
		return null
	var preview := Node3D.new()
	preview.name = "RoadPlacementPreview"
	preview.position = placement.position
	var heading: Vector3 = RoadStopsLoader.road_heading(road, placement.offset)
	# Keep both sides ready so switching options only changes visibility.
	for sign: float in [1.0, -1.0]:
		var shelter := BusStop3D.SHELTER_SCENE.instantiate() as Node3D
		shelter.name = "ForwardShelter" if sign > 0.0 else "ReverseShelter"
		shelter.transform = BusStop3D.shelter_transform(heading, Managers.road_stops.roadside_offset_metres, sign)
		BuildPreview.tint_model(shelter)
		preview.add_child(shelter)
	return preview

func make_rail_preview(placement: Dictionary) -> Node3D:
	var track: AbstractInfrLine = _infrastructure(placement)
	if track == null or track.curve == null:
		return null
	var model: BuildingMesh3D = make_rail_preview_model("STATION_PASS")
	if model == null:
		return null
	var anchor := Node3D.new()
	anchor.name = "RailPlacementPreview"
	anchor.transform = Transform3D(
		RailStop3D.placement_basis(track.curve, placement.offset, RailStationData.PlatformSide.RIGHT),
		placement.position)
	anchor.add_child(model)
	var marker := MeshInstance3D.new()
	marker.name = "StopMarker"
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	marker.mesh = sphere
	marker.position.y = 0.25
	BuildPreview.tint_model(marker)
	marker.hide()
	anchor.add_child(marker)
	return anchor


func make_rail_preview_model(station_type: String) -> BuildingMesh3D:
	var scenes: StationBuildingCatalog = _rail_platform(station_type)
	if scenes == null:
		return null
	var instance: Node = scenes.preview_scene.instantiate()
	if not instance is BuildingMesh3D:
		instance.free()
		return null
	var model := instance as BuildingMesh3D
	model.name = "PlatformModel"
	BuildPreview.tint_model(model)
	return model


func _rail_platform(station_type: String) -> StationBuildingCatalog:
	if not _rail_buildings.has(station_type):
		var scenes: StationBuildingCatalog = StationBuildingCatalog.rail_platform(station_type)
		if scenes != null:
			_rail_buildings[station_type] = scenes
	return _rail_buildings.get(station_type)


## Hit the supporting surface, so a nearby road or a bridge cannot steal placement.
func placement_at(position: Vector3, exclude: RID = RID(), view_forward: Vector3 = Vector3.ZERO) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.5, position - Vector3.UP * 2.0, CollisionLayers.WORLD)
	if exclude.is_valid():
		query.exclude = [exclude]
	var hit: Dictionary = get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	var surface: Node = hit.get("collider")
	while surface != null and not surface is InfrLine3D:
		surface = surface.get_parent()
	if surface is InfrLine3D:
		# Only road placement uses the view direction.
		return placement_on(surface.get_line(), position, view_forward)
	return {}

func placement_on(infrastructure: AbstractInfrLine, position: Vector3, view_forward: Vector3 = Vector3.ZERO) -> Dictionary:
	if infrastructure.curve == null or infrastructure.curve.get_point_count() < 2:
		return {}
	var road := infrastructure as RoadData
	var offset: float = infrastructure.curve.get_closest_offset(position)
	var center: Vector3 = infrastructure.curve.sample_baked(offset)
	var nodes: Array = infrastructure.get("nodes")
	var nearest_index: int = 0
	var nearest_distance: float = INF
	for index: int in nodes.size():
		var distance: float = position.distance_squared_to(nodes[index].position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	var placement := {"domain": "ROAD" if road != null else "RAIL", "infrastructure_num": infrastructure.num,
		"offset": offset, "node_index": nearest_index, "origin": position,
		"position": center}
	if road != null:
		var heading: Vector3 = RoadStopsLoader.road_heading(road, offset)
		var increasing := Enums.RoadStopDirection.ROAD_NODES_INCREASE
		var decreasing := Enums.RoadStopDirection.ROAD_NODES_DECREASE
		# Default to the player's physical side. Facing the other way changes
		# that side's label, while routing still uses the stored road direction.
		placement.direction = decreasing if (position - center).dot(heading.cross(Vector3.UP)) < 0.0 else increasing
		# Use the road direction closest to the captured view. Exact perpendicular
		# views have no preferred direction, so use the increasing direction there.
		placement.right_direction = decreasing if heading.dot(view_forward) < -0.0001 else increasing
	return placement

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

func _infrastructure(placement: Dictionary) -> AbstractInfrLine:
	if placement.get("domain") == "ROAD" and is_instance_valid(Managers.roads):
		return Managers.roads.storage._by_id.get(placement.get("infrastructure_num"))
	if placement.get("domain") == "RAIL" and is_instance_valid(Managers.rails):
		return Managers.rails.track_storage._by_id.get(placement.get("infrastructure_num"))
	return null

func placement_error(placement: Dictionary) -> String:
	var infrastructure: AbstractInfrLine = _infrastructure(placement)
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
		if placement.domain == "RAIL":
			for stop: AbstractStation in interchange.stops:
				if stop is RailStationData and stop.track_num == placement.infrastructure_num:
					return {"error": "This station already has a platform on this track."}
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

	var building: RailPlatform3D
	var platform_side: RailStationData.PlatformSide = RailStationData.PlatformSide.RIGHT
	if placement.domain == "RAIL":
		platform_side = placement.get("platform_side", RailStationData.PlatformSide.RIGHT) as RailStationData.PlatformSide
		if platform_side not in [RailStationData.PlatformSide.RIGHT, RailStationData.PlatformSide.LEFT]:
			return {"error": "Choose a platform side."}
		var scenes: StationBuildingCatalog = _rail_platform(station_type)
		if scenes == null:
			return {"error": "The rail platform definition is unavailable."}
		var instance: Node = scenes.building_scene.instantiate()
		if not instance is RailPlatform3D:
			instance.free()
			return {"error": "The rail platform scene requires a RailPlatform3D root."}
		building = instance
		if not is_instance_valid(building.platform_mesh):
			building.free()
			return {"error": "The rail platform is missing its BuildingMesh3D."}
	if created_interchange:
		interchange = catalog.create_runtime_interchange(title, town)

	var stop: AbstractStation
	if placement.domain == "ROAD":
		var road_stop := RoadStationData.new(catalog.next_stop_num())
		road_stop.road_num = placement.infrastructure_num
		# Like rail stops: the clicked curve distance, kept as nearest node + offset.
		road_stop.anchor = LineAnchor.at_curve_offset(_infrastructure(placement), placement.offset)
		road_stop.direction = direction
		road_stop.position = placement.position
		stop = road_stop
	else:
		var rail_stop := RailStationData.new(catalog.next_stop_num())
		rail_stop.track_num = placement.infrastructure_num
		# The clicked curve distance, kept as nearest node + offset so later edits elsewhere leave it.
		rail_stop.anchor = LineAnchor.at_curve_offset(_infrastructure(placement), placement.offset)
		rail_stop.position = placement.position
		rail_stop.station_type = station_type
		rail_stop.platform_side = platform_side
		rail_stop.hide_building = placement.get("hide_platform", false)
		stop = rail_stop
	var error: Error = catalog.register_stop(stop, interchange.num)
	if error != OK:
		if building != null:
			building.free()
		if created_interchange:
			catalog.interchanges.erase(interchange)
			catalog.by_num.erase(interchange.num)
		return {"error": "The stop could not be registered."}
	if company != null:
		company.spend(CompanyData.STOP_COST)
	stop.connected_town = interchange.connected_town
	if interchange.connected_town != null:
		interchange.connected_town.connect_new_station(stop)
	if stop is RoadStationData:
		Managers.road_stops.add_runtime_stop(stop)
	else:
		Managers.stations.add_runtime_stop(stop, building)
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
