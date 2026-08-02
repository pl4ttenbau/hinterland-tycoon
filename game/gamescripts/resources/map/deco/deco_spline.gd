@icon("res://assets/icons/icon_deco_white.png")
class_name DecoSplineData extends GameEntityData

const SCENE_PATH_TEMPLATE = "res://assets/meshes/deco/%s/%s_spline.tscn"

@export var type_key: StringName
@export var position: Vector3
@export var points: Array[Vector3] = []

func _init():
	super(Enums.EntityTypes.DECO_SPLINE)
	
func get_scene_path() -> String:
	return SCENE_PATH_TEMPLATE % [self.type_key, self.type_key]

static func from_dict(_dict: Dictionary) -> DecoSplineData:
	var spline_obj: DecoSplineData = DecoSplineData.new()
	spline_obj.type_key = _dict.get("type")
	if _dict.has("position"):
		spline_obj.position = WorldUtils.vec3_from_float_arr(_dict.get("position"))
	for point_dict in _dict.get("points"):
		var pt_pos_arr = point_dict.get("pos")
		var point_vec3 = WorldUtils.vec3_from_float_arr(pt_pos_arr)
		spline_obj.points.append(point_vec3)
	return spline_obj
	
func spawn() -> DecoSpline3D:
	var scene: Resource = load(self.get_scene_path())
	var outer_spline: DecoSpline3D = scene.instantiate() as DecoSpline3D
	outer_spline.spline = self
	return outer_spline
