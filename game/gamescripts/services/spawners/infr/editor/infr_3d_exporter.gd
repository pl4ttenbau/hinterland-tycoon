@tool
@icon("res://assets/icons/icon_gears_white.png")
class_name Infr3DExporter extends RefCounted

static func print_infr3d_to_log(infr3d: EditorInfrLine3D):
	var rail_dict: Dictionary = infr3d_to_dict(infr3d)
	var rail_dict_str: String = JSON.stringify(rail_dict, "\t", false)
	var final_json: String = replace_vec3_tuples_with_float_arr(rail_dict_str)
	DisplayServer.clipboard_set(final_json)
	print(final_json)

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
	var node_dict: Dictionary = {}
	# add position
	var rel_pos: Vector3 = infr3d_curve.get_point_position(curve_i)
	var abs_pos: Vector3 = start_pos + rel_pos
	node_dict.set("pos", WorldUtils.get_rounded_vec_3(abs_pos))
	# add handle
	var is_first_or_last = curve_i == 0 || curve_i == infr3d_curve.point_count -1
	if !is_first_or_last:
		var rel_handle_in: Vector3 = infr3d_curve.get_point_in(curve_i)
		node_dict.set("handleIn", WorldUtils.get_rounded_vec_3(rel_handle_in))
	return node_dict

static func place_on_ground(infr3d: EditorInfrLine3D):
	# var new_curve: Curve3D = Curve3D.new()
	for curve_i in range(infr3d.curve.point_count):
		var old_point_local_pos: Vector3 = infr3d.curve.get_point_position(curve_i)
		var old_point_global_pos: Vector3 = infr3d.to_global(old_point_local_pos)
		var global_terr_h: float = EditorUtils.get_y_at_pos(old_point_global_pos)
		if global_terr_h <= 0 || global_terr_h == NAN:
			Loggie.error("error while getting terrain height")
			continue
		var global_infr_h: float = global_terr_h + .2
		var new_global_pos: Vector3 = Vector3(old_point_global_pos.x, global_infr_h, old_point_global_pos.z)
		var new_local_pos: Vector3 = infr3d.to_local(new_global_pos)
		infr3d.curve.set_point_position(curve_i, new_local_pos)
	#infr3d.curve = new_curve
