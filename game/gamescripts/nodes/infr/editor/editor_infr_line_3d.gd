@tool
@icon("res://assets/icons/icon_infr_node.png")
class_name EditorInfrLine3D extends LinePath3D

const RAIL_COLOR = Color.BLACK
const ROAD_COLOR = Color.DARK_ORANGE

@export var num: int = -1
@export var infr_name: String
@export var infr_domain: Enums.InfrDomain

@export var color: Color:
	get(): return self._get_color()

#region Initialization
static func of(_domain: Enums.InfrDomain, _num: int, _name: String = "unnamed") -> EditorInfrLine3D:
	var inst := EditorInfrLine3D.new()
	inst.infr_domain = _domain
	inst.num = _num
	inst.infr_name = _name
	# auto-set node name
	inst.name = inst._get_node_name()
	return inst
	
func _enter_tree():
	super()
	self.material.set("shader_parameter/line_width", .25)
	self.material.set("shader_parameter/color", self.color)
#endregion

#region Curve
func create_curve_from_dict(infr_dict: Dictionary, smooth: bool = false):
	self.curve = Curve3D.new()
	for point in infr_dict.points:
		var abs_pos = WorldUtils.vec3_from_float_arr(point.pos)
		var rel_pos: Vector3 = abs_pos - self.position
		self.curve.add_point(rel_pos)
	if smooth:
		InfrUtils.smooth_curve3d(self.curve)
#endregion

#region Helper-Methods
func _get_color() -> Color:
	if self.infr_domain == Enums.InfrDomain.RAIL:
		return RAIL_COLOR
	elif self.infr_domain == Enums.InfrDomain.ROAD:
		return ROAD_COLOR
	return Color.MAGENTA
	
func _get_node_name() -> String:
	var name_prefix: String = "RailTrack"
	if self.infr_domain == Enums.InfrDomain.ROAD:
		name_prefix = "RoadWay"
	return name_prefix + "_" + str(self.num)
#endregion
