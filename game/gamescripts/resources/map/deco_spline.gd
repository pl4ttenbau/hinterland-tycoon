@icon("res://assets/icons/icon_deco_white.png")
class_name DecoSplineData extends Resource

@export var spline_type: StringName
@export var position: Vector3
@export var points: Array[Vector3] = []

static func from_dict(_dict: Dictionary) -> DecoSplineData:
	var spline_obj: DecoSplineData = DecoSplineData.new()
	spline_obj.spline_type = _dict.get("type")
	if _dict.has("position"):
		spline_obj.position = WorldUtils.vec3_from_float_arr(_dict.get("position"))
	for point_arr in _dict.get("points") as Array:
		var point_vec3 = WorldUtils.vec3_from_float_arr(point_arr.pos)
		spline_obj.points.append(point_vec3)
	return spline_obj
