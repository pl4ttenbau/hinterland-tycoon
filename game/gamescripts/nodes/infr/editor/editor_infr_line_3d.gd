@tool
@icon("res://assets/icons/icon_infr_node.png")
class_name EditorInfrLine3D extends LinePath3D

const RAIL_COLOR = Color.BLACK
const RAIL_MAT_PATH = "res://assets/packed/materials/line3d_rail_track_mat.tres"
const ROAD_COLOR = Color.DARK_ORANGE
const ROAD_MAT_PATH = "res://assets/packed/materials/line3d_roadway_mat.tres"

const LINE_WIDTH = .5

@export var num: int = -1
@export var infr_name: String
@export var infr_domain: Enums.InfrDomain

@export var color: Color:
	get(): return self._get_color()
	
@export var abs_aabb: AABB

@export_group("Smoothing")
@export var autosmooth: bool = false

@export_tool_button("Auto-Smooth Y")
var smooth_y = Callable(self, "do_smooth_y")

@export_tool_button("Auto-Smooth Full")
var smooth_full = Callable(self, "do_smooth_full")

@export_group("Export")
@export_tool_button("Export To Log")
var export_to_log = Callable(self, "do_export_to_log")

#region Initialization
static func of(_domain: Enums.InfrDomain, _num: int, _name: String = "unnamed", _autosmooth: bool = false) -> EditorInfrLine3D:
	var inst := EditorInfrLine3D.new()
	inst.infr_domain = _domain
	inst.num = _num
	inst.infr_name = _name
	inst.autosmooth = _autosmooth
	# auto-set node name
	inst.name = inst._get_node_name()
	return inst
	
static func ofRoad(_num: int, _name: String = "unnamed", _autosmooth: bool = false) -> EditorInfrLine3D:
	return EditorInfrLine3D.of(Enums.InfrDomain.ROAD, _num, _name, _autosmooth)

static func ofRail(_num: int, _name: String = "unnamed") -> EditorInfrLine3D:
	return EditorInfrLine3D.of(Enums.InfrDomain.RAIL, _num, _name, true)
	
func _enter_tree():
	super()
	self.material = self._get_material(self.infr_domain)
#endregion

#region Curve
func create_curve_from_dict(infr_dict: Dictionary):
	self.curve = Curve3D.new()
	var abs_points: PackedVector3Array = []
	var point_handle_in: PackedVector3Array = []
	# build abs pos & handle in vector array
	for point_json in infr_dict.points:
		abs_points.append(WorldUtils.vec3_from_float_arr(point_json.pos))
		point_handle_in.append(self._get_handle_in_from_point_json(point_json))
	# make relative positions from absolute ones & set to curve
	var point_i: int = 0
	for abs_pos in abs_points:
		var rel_pos: Vector3 = abs_pos - self.position
		var handle_in: Vector3 = point_handle_in[point_i]
		# add point pos with handles to curve
		self.curve.add_point(rel_pos, handle_in, -1 * handle_in)
		point_i += 1
	# generate aabb
	self.abs_aabb = InfrUtils.get_aabb(abs_points)
	if self.autosmooth:
		InfrUtils.smooth_curve3d(self.curve)

func _get_handle_in_from_point_json(point_json: Dictionary) -> Vector3:
	if point_json.has("handleIn"):
		var handle_in_arr: Array = point_json.get("handleIn")
		var point_in_vec3: Vector3 = WorldUtils.vec3_from_float_arr(handle_in_arr)
		return point_in_vec3
	else: return Vector3.ZERO
	
func do_smooth_y():
	InfrUtils.smooth_curve3d_y(self.curve)

func do_smooth_full():
	InfrUtils.smooth_curve3d(self.curve)
#endregion

#region Export
func do_export_to_log():
	pass
#endregion

#region Helper-Methods
func _get_color() -> Color:
	if self.infr_domain == Enums.InfrDomain.RAIL:
		return RAIL_COLOR
	elif self.infr_domain == Enums.InfrDomain.ROAD:
		return ROAD_COLOR
	return Color.MAGENTA
	
func _get_material(_domain: Enums.InfrDomain) -> ShaderMaterial:
	if _domain == Enums.InfrDomain.RAIL:
		return preload(RAIL_MAT_PATH) as ShaderMaterial
	elif _domain == Enums.InfrDomain.ROAD:
		return preload(ROAD_MAT_PATH) as ShaderMaterial
	return null
	
func _get_node_name() -> String:
	var name_prefix: String = "RailTrack"
	if self.infr_domain == Enums.InfrDomain.ROAD:
		name_prefix = "RoadWay"
	return name_prefix + "_" + str(self.num)
#endregion
