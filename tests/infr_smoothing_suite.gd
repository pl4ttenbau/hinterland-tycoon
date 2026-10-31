extends RefCounted

var failures: int = 0
var checks: int = 0
var tree: SceneTree

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run(test_tree: SceneTree) -> int:
	tree = test_tree
	# Count an aborted test as a failure too: runtime errors do not set the exit code.
	for test: StringName in [&"test_interpolation", &"test_recalculation", &"test_degenerate_points", &"test_vertical_smoothing", &"test_round_trip", &"test_runtime_options"]:
		check(call(test) == true, "%s completed" % test)
	print("Infrastructure smoothing tests: %d checks, %d failures" % [checks, failures])
	return 1 if failures > 0 else 0

func make_curve(points: Array[Vector3]) -> Curve3D:
	var curve := Curve3D.new()
	for point: Vector3 in points:
		curve.add_point(point)
	return curve

func check_curves_equal(actual: Curve3D, expected: Curve3D, message: String) -> void:
	check(actual.point_count == expected.point_count, message + ": point count")
	for idx: int in range(mini(actual.point_count, expected.point_count)):
		check(actual.get_point_position(idx).is_equal_approx(expected.get_point_position(idx)), message + ": position")
		check(actual.get_point_in(idx).is_equal_approx(expected.get_point_in(idx)), message + ": incoming handle")
		check(actual.get_point_out(idx).is_equal_approx(expected.get_point_out(idx)), message + ": outgoing handle")

## Independent reference: Barry-Goldman's recursive interpolation evaluates the
## Catmull-Rom curve directly, without using the production Bezier derivative formula.
func reference_sample(curve: Curve3D, segment: int, weight: float) -> Vector3:
	var p1: Vector3 = curve.get_point_position(segment)
	var p2: Vector3 = curve.get_point_position(segment + 1)
	var p0: Vector3 = curve.get_point_position(segment - 1) if segment > 0 else 2.0 * p1 - p2
	var p3: Vector3 = curve.get_point_position(segment + 2) if segment + 2 < curve.point_count else 2.0 * p2 - p1
	var t0: float = 0.0
	var t1: float = sqrt(p0.distance_to(p1))
	var t2: float = t1 + sqrt(p1.distance_to(p2))
	var t3: float = t2 + sqrt(p2.distance_to(p3))
	var t: float = lerpf(t1, t2, weight)
	var a1: Vector3 = p0.lerp(p1, (t - t0) / (t1 - t0))
	var a2: Vector3 = p1.lerp(p2, (t - t1) / (t2 - t1))
	var a3: Vector3 = p2.lerp(p3, (t - t2) / (t3 - t2))
	var b1: Vector3 = a1.lerp(a2, (t - t0) / (t2 - t0))
	var b2: Vector3 = a2.lerp(a3, (t - t1) / (t3 - t1))
	return b1.lerp(b2, (t - t1) / (t2 - t1))

func test_interpolation() -> bool:
	var curve: Curve3D = make_curve([Vector3.ZERO, Vector3(2, 1, 0), Vector3(12, 4, 8), Vector3(13, 3, 9)])
	var original: Curve3D = curve.duplicate()
	InfrUtils.smooth_curve3d(curve)
	for idx: int in range(curve.point_count):
		check(curve.get_point_position(idx) == original.get_point_position(idx), "Smoothing fixes every anchor, including the endpoints")
	for segment: int in range(curve.point_count - 1):
		for weight: float in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]:
			check(curve.sample(segment, weight).distance_to(reference_sample(original, segment, weight)) < 0.00003, "Bezier samples match independent centripetal interpolation")
	check(not is_equal_approx(curve.get_point_in(1).length(), curve.get_point_out(1).length()), "Unequal point spacing produces unequal handle lengths")
	# Curve direction must not affect its shape.
	var reversed: Curve3D = make_curve([Vector3(13, 3, 9), Vector3(12, 4, 8), Vector3(2, 1, 0), Vector3.ZERO])
	InfrUtils.smooth_curve3d(reversed)
	for idx: int in range(curve.point_count):
		check(curve.get_point_in(idx).is_equal_approx(reversed.get_point_out(curve.point_count - 1 - idx)), "Reversing points swaps the generated handles")
	var straight: Curve3D = make_curve([Vector3.ZERO, Vector3(3, 6, 9)])
	InfrUtils.smooth_curve3d(straight)
	check(straight.get_point_out(0) == Vector3(1, 2, 3), "Open start uses a chord-aligned tangent")
	check(straight.get_point_in(1) == Vector3(-1, -2, -3), "Open end uses a chord-aligned tangent")
	check(straight.sample(0, 0.25).is_equal_approx(Vector3(0.75, 1.5, 2.25)), "Two points interpolate as a straight line")
	return true

func test_recalculation() -> bool:
	var curve: Curve3D = make_curve([Vector3.ZERO, Vector3(5, 0, 0), Vector3(10, 0, 0)])
	InfrUtils.smooth_curve3d(curve)
	var before: Curve3D = curve.duplicate()
	InfrUtils.smooth_curve3d(curve)
	check_curves_equal(curve, before, "Repeated smoothing is idempotent")
	curve.set_point_position(2, Vector3(5, 2, 5))
	InfrUtils.smooth_curve3d(curve)
	check(not curve.get_point_out(1).is_equal_approx(before.get_point_out(1)), "Moving a point recalculates existing automatic handles")
	var fresh: Curve3D = make_curve([Vector3.ZERO, Vector3(5, 0, 0), Vector3(5, 2, 5)])
	InfrUtils.smooth_curve3d(fresh)
	check_curves_equal(curve, fresh, "Recalculation matches a fresh preview")
	curve.add_point(Vector3(6, 4, 15))
	InfrUtils.smooth_curve3d(curve)
	check(curve.get_point_out(2) != Vector3.ZERO, "Appending a point updates the former endpoint")
	curve.set_point_in(1, Vector3(-1, 3, -4))
	curve.set_point_out(1, Vector3(2, -6, 8))
	InfrUtils.smooth_curve3d(curve, true)
	check(curve.get_point_in(1) == Vector3(-1, 3, -4) and curve.get_point_out(1) == Vector3(2, -6, 8), "Loading preserves an authored asymmetric pair")
	return true

func test_degenerate_points() -> bool:
	var empty := Curve3D.new()
	InfrUtils.smooth_curve3d(empty)
	check(empty.point_count == 0, "Empty curves are accepted")
	var single: Curve3D = make_curve([Vector3(4, 5, 6)])
	single.set_point_in(0, Vector3.ONE)
	InfrUtils.smooth_curve3d(single)
	check(single.get_point_in(0) == Vector3.ZERO and single.get_point_out(0) == Vector3.ZERO, "A single point has no tangent")
	for fixture: Array in [
		[Vector3.ZERO, Vector3.ZERO],
		[Vector3.ZERO, Vector3.ZERO, Vector3(5, 2, 0), Vector3(5, 2, 0)],
		[Vector3.ZERO, Vector3(0.000001, 0, 0), Vector3(10, 0, 1)],
		[Vector3.ZERO, Vector3(5, 0, 0), Vector3.ZERO],
	]:
		var points: Array[Vector3] = []
		points.assign(fixture)
		var curve: Curve3D = make_curve(points)
		InfrUtils.smooth_curve3d(curve)
		for idx: int in range(curve.point_count):
			check(curve.get_point_in(idx).is_finite() and curve.get_point_out(idx).is_finite(), "Coincident points and reversals have finite handles")
			check(curve.get_point_position(idx) == points[idx], "Degenerate input does not delete or move points")
	return true

func test_vertical_smoothing() -> bool:
	var curve: Curve3D = make_curve([Vector3.ZERO, Vector3(6, 2, 0), Vector3(12, 3, 6)])
	InfrUtils.smooth_curve3d(curve)
	curve.set_point_in(1, curve.get_point_in(1) * Vector3(2, 9, 2))
	curve.set_point_out(1, curve.get_point_out(1) * Vector3(3, 9, 3))
	var before: Curve3D = curve.duplicate()
	InfrUtils.smooth_curve3d_y(curve)
	for idx: int in range(curve.point_count):
		check(curve.get_point_in(idx).x == before.get_point_in(idx).x and curve.get_point_in(idx).z == before.get_point_in(idx).z, "Y smoothing preserves incoming horizontal geometry")
		check(curve.get_point_out(idx).x == before.get_point_out(idx).x and curve.get_point_out(idx).z == before.get_point_out(idx).z, "Y smoothing preserves outgoing horizontal geometry")
	check(curve.get_point_in(1).normalized().is_equal_approx(-curve.get_point_out(1).normalized()), "Y smoothing scales grade to each handle's horizontal length")
	check(curve.get_point_in(0) == Vector3.ZERO and curve.get_point_out(2) == Vector3.ZERO, "Y smoothing retains collapsed endpoint handles")
	return true

func test_round_trip() -> bool:
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRoad(91, "Smoothing fixture", true)
	tree.root.add_child(line)
	line.curve = make_curve([Vector3.ZERO, Vector3(2, 1, 0), Vector3(12, 4, 8), Vector3(13, 3, 9)])
	InfrUtils.smooth_curve3d(line.curve)
	# A real text JSON round trip catches arrays vs Vector3 display strings as well
	# as missing endpoint handles and accidentally mirrored outgoing handles.
	var exported: Dictionary = Infr3DExporter.infr3d_to_road_dict(line)
	var json: String = Infr3DExporter.replace_vec3_tuples_with_float_arr(JSON.stringify(exported))
	var data: Dictionary = JSON.parse_string(json)
	var reloaded: EditorInfrLine3D = RoadMapper.editor_line_from_data(data)
	reloaded.create_curve_from_dict(data)
	check_curves_equal(reloaded.curve, line.curve, "Editor JSON round trip")
	var road: RoadData = RoadMapper.road_from_data_json(data)
	road.build_curve()
	check_curves_equal(road.curve, line.curve, "Runtime road JSON round trip")
	var rail_data: Dictionary = data.duplicate(true)
	rail_data["type"] = "NORMAL_GAUGE"
	var rail: RailTrackData = RailMapper.rail_track_from_dict(rail_data)
	rail.build_curve()
	check_curves_equal(rail.curve, line.curve, "Runtime rail JSON round trip")
	# Legacy maps with only handleIn must still load mirrored handleOut values.
	var legacy: Dictionary = {"num": 92, "name": "Legacy", "points": [
		{"pos": [0, 0, 0]}, {"pos": [5, 1, 2], "handleIn": [-1, -0.5, 0]}, {"pos": [10, 2, 5]}
	]}
	var legacy_line: EditorInfrLine3D = RoadMapper.editor_line_from_data(legacy)
	legacy_line.create_curve_from_dict(legacy)
	check(legacy_line.curve.get_point_out(1) == Vector3(1, 0.5, 0), "Legacy editor handles remain mirrored")
	var legacy_road: RoadData = RoadMapper.road_from_data_json(legacy)
	legacy_road.build_curve()
	check(legacy_road.curve.get_point_out(1) == Vector3(1, 0.5, 0), "Legacy runtime road handles remain mirrored")
	var legacy_node := RailNodeData.new()
	legacy_node.parse_and_add_special(legacy.points[1])
	check(legacy_node.handle_out == Vector3(1, 0.5, 0), "Legacy runtime rail handles remain mirrored")
	line.free()
	reloaded.free()
	legacy_line.free()
	# Infrastructure nodes refer back to their track; release fixture cycles.
	road.nodes.clear()
	legacy_road.nodes.clear()
	rail.nodes.clear()
	return true

func test_runtime_options() -> bool:
	var data: Dictionary = {"num": 93, "autosmooth": false, "points": [
		{"pos": [0, 0, 0]}, {"pos": [5, 1, 2]}, {"pos": [10, 2, 5]}
	]}
	var road: RoadData = RoadMapper.road_from_data_json(data)
	road.build_curve()
	check(road.curve.get_point_in(1) == Vector3.ZERO and road.curve.get_point_out(1) == Vector3.ZERO, "autosmooth=false is respected at runtime")
	road.nodes.clear()
	data.erase("autosmooth")
	road = RoadMapper.road_from_data_json(data)
	var completion: Array[bool] = [false]
	road.curve_built.connect(func(curve: Curve3D) -> void: completion[0] = curve.get_point_out(0) != Vector3.ZERO)
	road.build_curve()
	check(completion[0], "curve_built observers receive the smoothed curve")
	road.nodes.clear()
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRoad(93, "Unsmoothed", false)
	tree.root.add_child(line)
	line.curve = make_curve([Vector3.ZERO, Vector3(5, 1, 2), Vector3(10, 2, 5)])
	check(Infr3DExporter.infr3d_to_road_dict(line).autosmooth == false, "Export preserves the road's smoothing option")
	line.free()
	return true
