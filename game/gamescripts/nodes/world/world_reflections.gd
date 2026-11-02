extends Node3D
## Small, static outdoor captures near depots and stations. Sky reflections cover
## the rest of the map. No per-frame polling or continuously updating probes.

@export_range(0, 8, 1) var max_probes: int = 4
@export var probe_size := Vector3(80.0, 30.0, 80.0)
@export_range(0.0, 200.0, 1.0) var minimum_spacing: float = 60.0
@export_range(0.1, 5.0, 0.1) var refresh_delay: float = 0.75

# Default, Landscape, Buildings, Infrs, Deco. Exclude Water and Vehicles.
const STATIC_CAPTURE_MASK: int = 1 | 4 | 8 | 16 | 32
const CAPTURE_SETTLE_FRAMES: int = 8

var _refresh_timer: Timer
var _generation: int = 0

func _ready() -> void:
	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	_refresh_timer.timeout.connect(_refresh_probes)
	add_child(_refresh_timer)
	SignalBus.map_spawned.connect(request_refresh.unbind(1))
	SignalBus.rails_spawned.connect(request_refresh.unbind(1))
	SignalBus.rail_spawned.connect(request_refresh.unbind(1))
	SignalBus.roads_spawned.connect(request_refresh)
	SignalBus.road_spawned.connect(request_refresh.unbind(1))
	SignalBus.town_buildings_spawned.connect(request_refresh)
	SignalBus.node_station_links_spawned.connect(request_refresh)
	SignalBus.industries_spawned.connect(request_refresh)
	SignalBus.industry_spawned.connect(request_refresh.unbind(1))
	request_refresh()

## Coalesce loading/building events; never refresh on the periodic world tick.
func request_refresh() -> void:
	if not is_inside_tree():
		return
	_generation += 1
	_refresh_timer.start(refresh_delay)

func _exit_tree() -> void:
	_generation += 1

func _refresh_probes() -> void:
	var world: WorldMapScene = GlobalState.world_container
	if not is_instance_valid(world) or not world.is_ancestor_of(self):
		return
	var generation: int = _generation
	var sites: Array[Vector3] = _select_sites(_collect_candidates())
	for child: Node in get_children():
		if child is ReflectionProbe:
			remove_child(child)
			child.queue_free()
	for site: Vector3 in sites:
		if generation != _generation or not is_inside_tree():
			return
		var probe: ReflectionProbe = _make_probe()
		probe.name = "LocalReflection%d" % get_child_count()
		add_child(probe)
		# Global positions stay correct even where DayEnvironment is translated.
		probe.global_position = site + Vector3.UP * 4.0
		# UPDATE_ONCE takes six faces plus filtering. Stagger captures rather than
		# making every probe render its surroundings in the same loading frame.
		for frame: int in range(CAPTURE_SETTLE_FRAMES):
			await get_tree().process_frame
			if generation != _generation or not is_inside_tree():
				return

func _collect_candidates() -> Array[Vector3]:
	var candidates: Array[Vector3] = []
	if is_instance_valid(Managers.depots):
		for depot: RailDepot3D in Managers.depots.rail_containers:
			if is_instance_valid(depot):
				# Look out into the yard, rather than capture from inside the shed.
				candidates.append(depot.global_position - depot.global_basis.z * 12.0)
	for station: RailStationData in GlobalState.station_objs:
		if is_instance_valid(station) and not station.node_stations.is_empty():
			candidates.append(station.position)
	return candidates

func _select_sites(candidates: Array[Vector3]) -> Array[Vector3]:
	var sites: Array[Vector3] = []
	for candidate: Vector3 in candidates:
		if sites.size() >= max_probes:
			break
		if not candidate.is_finite():
			continue
		var overlaps: bool = false
		for site: Vector3 in sites:
			var offset := Vector2(candidate.x - site.x, candidate.z - site.z)
			if offset.length_squared() < minimum_spacing * minimum_spacing:
				overlaps = true
				break
		if not overlaps:
			sites.append(candidate)
	return sites

func _make_probe() -> ReflectionProbe:
	var probe := ReflectionProbe.new()
	probe.size = probe_size
	probe.max_distance = 120.0
	probe.blend_distance = 8.0
	probe.intensity = 1.0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.interior = false
	probe.box_projection = false
	probe.enable_shadows = false
	probe.cull_mask = STATIC_CAPTURE_MASK
	probe.mesh_lod_threshold = 4.0
	# Keep diffuse sky lighting consistent inside and outside the captures.
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	return probe
