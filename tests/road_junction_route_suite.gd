## Road routing through editor-style, auto-connected 3-way junctions.
##
## The fixture is a small town: two stations joined by three road segments that meet at two
## 3-way junctions. Everything is built from the same JSON shape the editor saves
## ("cross": {"autoConnectiveRoads": [...]}), so the mapper, the graph, the U-turn planner and
## the vehicle all see what a real map gives them.
##
##     z = -160        o  road 3 end (dead end)
##                     |
##     z = -120   o    B  station B: road 3, node 2
##                |    |
##     z =  -80   J1---J2  road 2 runs east from J1 to J2
##                |    |
##     z =  -40   A    o  road 3 start (dead end)
##                |
##     z =    0   o  road 1 start (dead end, depot)
##              x = 0  x = 80
##
## Road 1 runs north from the depot through station A to J1. Road 4 is a short dead-end spur
## north of J1, which makes J1 a real 3-way junction of three road ends. J2 is a T: road 2 ends
## on road 3's middle node, so road 3 carries the cross on an interior node. Both junction kinds
## occur in the shipped maps.
##
## Roads run north (towards -z) or east, so "increasing node order" is northbound/eastbound.
## Vector3.FORWARD (-z) is a northbound heading.
extends RefCounted

const JUNCTION_WEST := Vector3(0, 0, -80)
const JUNCTION_EAST := Vector3(80, 0, -80)
## The real U-turn starts a few metres before the road end (half the vehicle plus margin).
## Anything this close to a junction centre is a turn inside the junction.
const JUNCTION_RADIUS: float = 12.0
const DEAD_ENDS: Array[Vector3] = [Vector3(0, 0, 0), Vector3(80, 0, -160), Vector3(80, 0, -40), Vector3(0, 0, -120)]
const BUS: String = "daimler_1911_bus"

var failed: int = 0
var passed: int = 0
var tree: SceneTree
## Graph-only copy of the town: no views, no global managers.
var roads := RoadStore.new()
var network := RoadPathfinder.new()
## Stops hold their interchange weakly, so the suite keeps them alive.
var interchanges: Array[InterchangeData] = []

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error(message)

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	GameTypes.ensure_initialized()
	for definition: Dictionary in _town():
		_store(roads, _make_road(definition))
	network.build(roads.get_all())
	for test: StringName in [&"test_auto_crosses_are_read", &"test_route_through_both_junctions",
			&"test_dead_end_spur", &"test_overlap_without_cross", &"test_one_way_stop_approach",
			&"test_reversal_avoids_junctions", &"test_heading", &"test_vehicle_legs"]:
		if await call(test) != true:
			check(false, "%s aborted" % test)
	print("Road junction route tests: %d passed, %d failed" % [passed, failed])
	return 0 if failed == 0 else 1

#region Fixture
## The town above, as the editor writes it. Every junction lists its partners on every
## road that meets there, which is what the editor's auto-connect produces.
func _town() -> Array[Dictionary]:
	return [
		_road(1, [[0, 0, 0], [0, 0, -40], {"pos": [0, 0, -80], "auto": [2, 4]}]),
		_road(2, [{"pos": [0, 0, -80], "auto": [1, 4]}, [40, 0, -80], {"pos": [80, 0, -80], "auto": [3]}]),
		_road(3, [[80, 0, -40], {"pos": [80, 0, -80], "auto": [2]}, [80, 0, -120], [80, 0, -160]]),
		_road(4, [{"pos": [0, 0, -80], "auto": [1, 2]}, [0, 0, -120]]),
	]

## Points are either a plain position or {"pos", "auto"} for a junction node.
## Autosmooth is off so road lengths stay exact and the expected distances are plain sums.
func _road(num: int, points: Array) -> Dictionary:
	var json_points: Array = []
	for point: Variant in points:
		if point is Dictionary:
			json_points.append({"pos": point.pos, "cross": {"autoConnectiveRoads": point.auto}})
		else:
			json_points.append({"pos": point})
	return {"num": num, "type": "rural_road", "autosmooth": false, "points": json_points}

func _make_road(definition: Dictionary) -> RoadData:
	var road: RoadData = RoadMapper.road_from_data_json(definition)
	road.build_curve()
	return road

## Fill a store directly, as the other road suites do, without the loader's side effects.
func _store(store: RoadStore, road: RoadData) -> void:
	store._list.append(road)
	store._by_id[road.num] = road

func _stop(num: int, road_num: int, node_index: int, direction: Enums.RoadStopDirection) -> RoadStationData:
	var stop := RoadStationData.new(num, "Station %d" % num)
	interchanges.append(InterchangeData.new())
	stop.interchange = interchanges.back()
	stop.interchange.num = num
	stop.road_num = road_num
	stop.anchor = LineAnchor.new(node_index)
	stop.direction = direction
	return stop
#endregion

#region Path helpers
## Road numbers in travel order, each listed once per stretch driven on it.
func _roads_along(path: Array[RoadNode]) -> Array[int]:
	var result: Array[int] = []
	for node: RoadNode in path:
		if result.is_empty() or result.back() != node.parent_line.num:
			result.append(node.parent_line.num)
	return result

## Where the path turns back on the same road: the vehicle would need a U-turn there.
## The graph treats any node as a free place to reverse, so this is what we look for.
func _reversals(path: Array[RoadNode]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index: int in range(1, path.size() - 1):
		var before: RoadNode = path[index - 1]
		var here: RoadNode = path[index]
		var after: RoadNode = path[index + 1]
		if before.parent_line != here.parent_line or here.parent_line != after.parent_line:
			continue
		var incoming: float = here.offset() - before.offset()
		var outgoing: float = after.offset() - here.offset()
		if incoming * outgoing < 0.0:
			result.append(here.position)
	return result

func _near_junction(position: Vector3) -> bool:
	var flat := Vector3(position.x, 0, position.z)
	return flat.distance_to(JUNCTION_WEST) < JUNCTION_RADIUS or flat.distance_to(JUNCTION_EAST) < JUNCTION_RADIUS

func _near_dead_end(position: Vector3) -> bool:
	var flat := Vector3(position.x, 0, position.z)
	for end: Vector3 in DEAD_ENDS:
		if flat.distance_to(end) < JUNCTION_RADIUS:
			return true
	return false
#endregion

#region Graph
## autoConnectiveRoads must reach RoadCross, and the interior junction node must become a
## graph node. Plain curve-shape nodes stay out of the graph.
func test_auto_crosses_are_read() -> bool:
	var west: RoadCross = roads._by_id[1].nodes[2].cross
	check(west != null and west.connecting_roads.size() == 2 and 2 in west.connecting_roads and 4 in west.connecting_roads,
		"The mapper keeps autoConnectiveRoads on a road end")
	var east: RoadCross = roads._by_id[3].nodes[1].cross
	check(east != null and east.connecting_roads == [2], "The mapper keeps autoConnectiveRoads on an interior node")
	check(roads._by_id[1].nodes[1].cross == null, "Ordinary nodes get no cross")
	# Two ends for each of the four roads, plus road 3's interior junction node.
	check(network.graph_node_count() == 9, "Graph holds road ends and junction nodes only (got %d)" % network.graph_node_count())
	return true

## The basic job: A to B passes J1, all of road 2 and J2, then the same way back.
func test_route_through_both_junctions() -> bool:
	var a: RoadNode = roads._by_id[1].nodes[1]
	var b: RoadNode = roads._by_id[3].nodes[2]
	var there: Array[RoadNode] = network.find_path(a, b)
	check(_roads_along(there) == [1, 2, 3], "A to B drives roads 1, 2, 3 (got %s)" % [_roads_along(there)])
	check(is_equal_approx(network.path_length(there), 160.0), "A to B is 40 + 80 + 40 m (got %.1f)" % network.path_length(there))
	check(not there.is_empty() and there.front() == a and there.back() == b, "The path starts and ends at the requested nodes")
	check(_reversals(there).is_empty(), "A to B never turns back")
	var back: Array[RoadNode] = network.find_path(b, a)
	check(_roads_along(back) == [3, 2, 1], "B to A uses the same junctions in reverse (got %s)" % [_roads_along(back)])
	check(is_equal_approx(network.path_length(back), 160.0), "B to A has the same length")
	return true

## The spur is reachable from both sides of J1 and is never a shortcut for anything else.
func test_dead_end_spur() -> bool:
	var spur_end: RoadNode = roads._by_id[4].nodes[1]
	var from_a: Array[RoadNode] = network.find_path(roads._by_id[1].nodes[1], spur_end)
	check(_roads_along(from_a) == [1, 4] and is_equal_approx(network.path_length(from_a), 80.0),
		"A reaches the spur end straight through J1")
	var from_b: Array[RoadNode] = network.find_path(roads._by_id[3].nodes[2], spur_end)
	check(_roads_along(from_b) == [3, 2, 4] and is_equal_approx(network.path_length(from_b), 160.0),
		"B reaches the spur by turning from road 2 into road 4 at J1")
	return true

## A road lying across road 2 without a cross is a bridge or a mistake, never a junction.
## Separate graph, so the shared town stays untouched.
func test_overlap_without_cross() -> bool:
	var store := RoadStore.new()
	for definition: Dictionary in _town():
		_store(store, _make_road(definition))
	# Road 5 crosses road 2's middle node at the same height, but nobody lists it.
	_store(store, _make_road(_road(5, [[40, 0, -40], [40, 0, -80], [40, 0, -120]])))
	var graph := RoadPathfinder.new()
	graph.build(store.get_all())
	check(graph.find_path(store._by_id[5].nodes[0], store._by_id[1].nodes[0]).is_empty(),
		"An unlisted overlap does not connect roads")
	return true

## One-sided stops (new stops default to ROAD_NODES_INCREASE) decide where a route must reverse.
## Serving B from the wrong side has to go past it to road 3's dead end, turn, and come back.
func test_one_way_stop_approach() -> bool:
	var a: RoadNode = roads._by_id[1].nodes[1]
	var northbound := _stop(901, 3, 2, Enums.RoadStopDirection.ROAD_NODES_INCREASE)
	var path: Array[RoadNode] = network.find_path(a, northbound.route_anchor(roads))
	check(is_equal_approx(network.path_length(path), 160.0) and _reversals(path).is_empty(),
		"A northbound stop is served directly when arriving northbound")
	var southbound := _stop(902, 3, 2, Enums.RoadStopDirection.ROAD_NODES_DECREASE)
	path = network.find_path(a, southbound.route_anchor(roads))
	# 40 to J1, 80 along road 2, 80 from J2 up to road 3's end, 40 back down to B.
	check(is_equal_approx(network.path_length(path), 240.0), "A southbound stop is served after turning at road 3's end (got %.1f)" % network.path_length(path))
	var turns: Array[Vector3] = _reversals(path)
	check(turns.size() == 1 and turns[0].is_equal_approx(Vector3(80, 0, -160)),
		"The only reversal is at road 3's dead end (got %s)" % [turns])
	return true

## Regression for "reaches the right crossing, turns, then turns back".
## A westbound stop on road 2, approached from J1 (eastbound), needs a reversal somewhere.
## The old graph reversed for free at J2, i.e. a U-turn inside the junction. Now the route
## turns into road 3 and reverses at its nearer dead end, the road's start south of J2.
func test_reversal_avoids_junctions() -> bool:
	var westbound := _stop(903, 2, 1, Enums.RoadStopDirection.ROAD_NODES_DECREASE)
	var path: Array[RoadNode] = network.find_path(roads._by_id[1].nodes[1], westbound.route_anchor(roads))
	check(not path.is_empty(), "The westbound stop on road 2 is reachable")
	for turn: Vector3 in _reversals(path):
		check(not _near_junction(turn), "Route reverses inside a junction at %s; it should use a dead end" % turn)
	var turns: Array[Vector3] = _reversals(path)
	check(turns.size() == 1 and turns[0].is_equal_approx(Vector3(80, 0, -40)),
		"The reversal uses road 3's southern dead end, the nearest one (got %s)" % [turns])
	# 40 to J1, 80 along road 2, 40 down road 3 and back, 40 west to the stop.
	check(is_equal_approx(network.path_length(path), 240.0), "Detour length is physical metres (got %.1f)" % network.path_length(path))
	return true

## A start with a heading never drives off backwards: a target behind means carrying on to a
## dead end, turning there, and coming back. Without a heading the shorter way is fine.
func test_heading() -> bool:
	var road_1: RoadData = roads._by_id[1]
	var b: RoadNode = roads._by_id[3].nodes[2]
	# Southbound on road 1 at 60 m, B lies behind (north, through J1).
	var start := RoadRouteAnchor.at(road_1, 60.0)
	var path: Array[RoadNode] = network.find_path(start, b, -1)
	var turns: Array[Vector3] = _reversals(path)
	check(turns.size() == 1 and turns[0].is_equal_approx(Vector3(0, 0, 0)),
		"Facing away from B, the route turns at road 1's dead end (got %s)" % [turns])
	check(is_equal_approx(network.path_length(path), 60.0 + 80.0 + 80.0 + 40.0), "Southbound detour length (got %.1f)" % network.path_length(path))
	check(path.size() > 1 and path[1].offset() < start.offset(), "The first move follows the heading")
	path = network.find_path(start, b, 1)
	check(_reversals(path).is_empty() and is_equal_approx(network.path_length(path), 20.0 + 80.0 + 40.0),
		"Facing B, the route goes straight through both junctions")
	path = network.find_path(start, b)
	check(is_equal_approx(network.path_length(path), 140.0), "Without a heading the shortest way is taken")

	# A ring lets a vehicle come round instead of reversing. Road 5 closes J1 - spur - road 5 -
	# road 3 - J2 - road 2, and road 3 loses its southern stub, so the only dead end left is
	# road 1's start, behind the vehicle.
	var store := RoadStore.new()
	var town: Array[Dictionary] = _town()
	town[2] = _road(3, [{"pos": [80, 0, -80], "auto": [2]}, [80, 0, -120], {"pos": [80, 0, -160], "auto": [5]}])
	town[3] = _road(4, [{"pos": [0, 0, -80], "auto": [1, 2]}, {"pos": [0, 0, -120], "auto": [5]}])
	town.append(_road(5, [{"pos": [0, 0, -120], "auto": [4]}, {"pos": [80, 0, -160], "auto": [3]}]))
	for definition: Dictionary in town:
		_store(store, _make_road(definition))
	var ring := RoadPathfinder.new()
	ring.build(store.get_all())
	# Northbound on road 1 towards a westbound stop on road 2: straight on at J1 up the spur,
	# round by road 5 and road 3, then west at J2. No U-turn, and none inside J2 either.
	var westbound := _stop(904, 2, 1, Enums.RoadStopDirection.ROAD_NODES_DECREASE)
	path = ring.find_path(RoadRouteAnchor.at(store._by_id[1], 60.0), westbound.route_anchor(store), 1)
	check(not path.is_empty() and _reversals(path).is_empty(), "On a ring the route needs no U-turn at all (got %s)" % [_reversals(path)])
	check(_roads_along(path) == [1, 4, 5, 3, 2], "The ring route is roads 1, 4, 5, 3, 2 (got %s)" % [_roads_along(path)])
	return true
#endregion

#region Vehicle
## Real views and managers: the executor's segment building, the U-turn planner and a bus
## driving a looping two-station plan.
func test_vehicle_legs() -> bool:
	var old_roads: RoadsLoader = Managers.roads
	var old_vehicles: VehiclePlacer = Managers.vehicles
	var old_interchanges: InterchangesLoader = Managers.interchanges
	var host := Node3D.new()
	tree.root.add_child(host)
	Managers.roads = RoadsLoader.new()
	Managers.vehicles = VehiclePlacer.new()
	Managers.interchanges = InterchangesLoader.new()
	for service: Node in [Managers.roads, Managers.vehicles, Managers.interchanges]:
		host.add_child(service)
	for definition: Dictionary in _town():
		var road: RoadData = _make_road(definition)
		_store(Managers.roads.storage, road)
		var view: RoadWay3D = RoadWay3D.of(road)
		Managers.roads.add_child(view)
		Managers.roads.storage.add_container(view)
	# Default stop direction, like stops placed in the game.
	var station_a := _stop(911, 1, 1, Enums.RoadStopDirection.ROAD_NODES_INCREASE)
	var station_b := _stop(912, 3, 2, Enums.RoadStopDirection.ROAD_NODES_INCREASE)
	Managers.interchanges.stops_by_num[911] = station_a
	Managers.interchanges.stops_by_num[912] = station_b
	for frame: int in range(4):
		await tree.process_frame

	_check_leg_planning(station_a, station_b)
	await _check_looping_bus()

	host.free()
	Managers.roads = old_roads
	Managers.vehicles = old_vehicles
	Managers.interchanges = old_interchanges
	return true

## The executor's own segment building, without driving: what would the U-turn planner do?
func _check_leg_planning(station_a: RoadStationData, station_b: RoadStationData) -> void:
	var storage: RoadStore = Managers.roads.storage
	var graph := RoadPathfinder.new()
	graph.build(storage.get_all())
	var executor := RoadPlanExecutor.new()
	var road_1: Path3D = storage.get_container_by_num(1).get_path_3d()
	var road_3: Path3D = storage.get_container_by_num(3).get_path_3d()

	# The executor derives the heading from the vehicle; northbound is +1 on both roads.
	check(executor._heading_along(road_1, 40.0, Vector3.FORWARD) == 1 and executor._heading_along(road_3, 80.0, Vector3.BACK) == -1
		and executor._heading_along(road_1, 40.0, Vector3.RIGHT) == 0, "Heading follows the vehicle's facing along the road")

	# Leaving A northbound towards B: two ordinary turns, no reversal at all.
	var start := RoadRouteAnchor.at(storage._by_id[1], 40.0)
	var segments: Array[Dictionary] = executor._make_segments(road_1, 40.0, graph.find_path(start, station_b.route_anchor(storage), 1))
	check(not segments.is_empty(), "Executor builds segments from A to B")
	check(RoadUTurnPlanner.prepare(segments, Vector3.FORWARD) == null, "A northbound bus at A drives to B without a U-turn")

	# Leaving B northbound with A behind: the path itself carries on to road 3's dead end and
	# reverses there; the planner splits it at that reversal. Never at J2.
	start = RoadRouteAnchor.at(storage._by_id[3], 80.0)
	segments = executor._make_segments(road_3, 80.0, graph.find_path(start, station_a.route_anchor(storage), 1))
	var turn: RoadUTurnPlanner.Approach = RoadUTurnPlanner.prepare(segments, Vector3.FORWARD)
	check(turn != null, "With A behind it, the bus at B plans a U-turn")
	if turn != null:
		var at: Vector3 = turn.path.to_global(turn.path.curve.sample_baked(turn.offset))
		check(_near_dead_end(at) and not _near_junction(at), "The U-turn from B is at a dead end (got %s)" % at)

## Two stations, looping on. Record every visit and every U-turn the bus starts.
## A correct run visits A, B, A, B and only ever turns at dead ends: road 3's end after B,
## road 1's start before serving the northbound stop A again.
func _check_looping_bus() -> void:
	var depot := RoadDepotData.new()
	depot.road_num = 1
	depot.road_pos = "START"
	var body: RoadVehicle3D = Managers.vehicles.spawn_road_vehicle_at_depot(BUS, depot)
	check(body != null, "Bus spawns at the depot (%s)" % Managers.vehicles.last_road_spawn_error)
	if body == null:
		return
	var a := RoadRoutePoint.new()
	a.kind = RoadRoutePoint.Kind.STOP
	a.target_num = 911
	var b := RoadRoutePoint.new()
	b.kind = RoadRoutePoint.Kind.STOP
	b.target_num = 912
	body.route_plan.points.assign([a, b])
	body.route_plan.repeat_route = true
	check(body.plan_execution.start(body), "Looping plan starts: %s" % body.plan_execution.status)

	var visits: Array[int] = []
	var turns: Array[Vector3] = []
	var point: int = body.plan_execution.current_point
	var turning: bool = false
	var furthest_east: float = body.global_position.x
	for frame: int in range(14000):
		await tree.physics_frame
		if not body.plan_execution.running:
			break
		furthest_east = maxf(furthest_east, body.global_position.x)
		# A finished visit moves current_point on (and wraps to 0 when looping).
		if body.plan_execution.current_point != point:
			visits.append(point)
			point = body.plan_execution.current_point
		var now_turning: bool = body.is_automatic_uturning()
		if now_turning and not turning:
			turns.append(body.global_position)
			# Before B has been served, any U-turn means the bus gave up on the junctions.
			if 1 not in visits:
				check(false, "U-turn at %s before reaching B (x reached %.1f)" % [body.global_position, furthest_east])
		turning = now_turning
		if visits.size() >= 4:
			break

	# Printed on success too: the turn positions are the useful part when this goes wrong.
	print("Looping bus: visits %s, U-turns at %s, status '%s'" % [visits, turns, body.plan_execution.status])
	check(body.plan_execution.running, "The looping plan is still running: %s" % body.plan_execution.status)
	check(visits == [0, 1, 0, 1], "Bus serves A, B, A, B in order (got %s)" % [visits])
	check(furthest_east > 75.0, "Bus crosses road 2 to J2 (x reached %.1f)" % furthest_east)
	for at: Vector3 in turns:
		check(not _near_junction(at), "U-turn inside a junction at %s" % at)
		check(_near_dead_end(at), "U-turn away from any dead end at %s" % at)
	check(turns.size() == 2, "One U-turn after B, one before A again (got %d)" % turns.size())
	body.free()
#endregion
