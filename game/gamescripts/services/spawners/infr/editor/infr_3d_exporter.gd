@tool
@icon("res://assets/icons/icon_gears_white.png")
class_name Infr3DExporter extends RefCounted

static func print_infr3d_to_log(infr3d: EditorInfrLine3D):
	var rail_dict: Dictionary = infr3d_to_dict(infr3d)
	var rail_dict_str: String = JSON.stringify(rail_dict, "  ", false)
	print(replace_vec3_tuples_with_float_arr(rail_dict_str))

## Vectror 3s are printed as string and float arrays are having newlines inbetween x y & z
## so instead, we replace the "( & )" after formatting the dict to a string
static func replace_vec3_tuples_with_float_arr(rail_dict_str: String) -> String:
	return rail_dict_str.replace("\"(", "[").replacen(")\"", "]")

static func infr3d_to_dict(infr3d: EditorInfrLine3D) -> Dictionary:
	if infr3d.infr_domain == Enums.InfrDomain.RAIL:
		return infr3d_to_rail_dict(infr3d)
	else:
		return infr3d_to_road_dict(infr3d)

static func infr3d_to_rail_dict(infr3d: EditorInfrLine3D) -> Dictionary:
	var rail_dict: Dictionary = {}
	rail_dict.set("name", "Generated Rail Track")
	rail_dict.set("num", -1)
	rail_dict.set("type", "NORMAL_GAUGE")
	var start_pos: Vector3 = infr3d.global_position
	# add nodes
	var nodes_arr: Array = infr3d_curve_to_node_json_arr(start_pos, infr3d.curve)
	rail_dict.set("points", nodes_arr)
	return rail_dict

static func infr3d_to_road_dict(infr3d: EditorInfrLine3D) -> Dictionary:
	var rail_dict: Dictionary = {}
	rail_dict.set("name", "Generated Roadway Track")
	rail_dict.set("num", -1)
	var start_pos: Vector3 = infr3d.global_position
	# add nodes
	var nodes_arr: Array = infr3d_curve_to_node_json_arr(start_pos, infr3d.curve)
	rail_dict.set("points", nodes_arr)
	return rail_dict

static func infr3d_curve_to_node_json_arr(start_pos: Vector3, infr3d_curve: Curve3D) -> Array:
	var node_pos_arr: Array = []
	for curve_i: int in range(infr3d_curve.point_count):
		var node_dict: Dictionary = infr3d_curve_index_to_node_json(start_pos, infr3d_curve, curve_i)
		node_pos_arr.append(node_dict)
	return node_pos_arr

static func infr3d_curve_index_to_node_json(start_pos: Vector3, infr3d_curve: Curve3D, curve_i: int) -> Dictionary:
	var rel_pos: Vector3 = infr3d_curve.get_point_position(curve_i)
	var abs_pos: Vector3 = start_pos + rel_pos
	var node_dict: Dictionary = {}
	node_dict.set("pos", abs_pos)
	return node_dict
