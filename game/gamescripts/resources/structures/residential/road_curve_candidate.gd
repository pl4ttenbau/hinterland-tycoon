@tool
## World-space road geometry prepared once for residence access searches in editor or game.
class_name RoadCurveCandidate extends RefCounted

var num: int
var curve: Curve3D

func _init(road_num: int, world_curve: Curve3D) -> void:
	num = road_num
	curve = world_curve

func is_valid() -> bool:
	return num >= 0 and curve != null and curve.point_count >= 2 and curve.get_baked_length() > 0.0

static func from_curve(road_num: int, local_curve: Curve3D, transform: Transform3D) -> RoadCurveCandidate:
	var world_curve := Curve3D.new()
	if local_curve != null:
		for index: int in range(local_curve.point_count):
			world_curve.add_point(transform * local_curve.get_point_position(index),
				transform.basis * local_curve.get_point_in(index), transform.basis * local_curve.get_point_out(index))
	return RoadCurveCandidate.new(road_num, world_curve)
