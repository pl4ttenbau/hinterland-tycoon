class_name PathCurveUtils extends RefCounted

static func split_curve(original_curve: Curve3D, cut_ratio: float) -> Array[Curve3D]:
	var curve_length = original_curve.get_baked_length()
	var split_offset = curve_length * cut_ratio
	var baked_points = original_curve.get_baked_points()
	
	var curve1 = Curve3D.new()
	var curve2 = Curve3D.new()
	
	var split_reached = false
	
	# Loop through the baked points to build the two new curves
	for i in range(baked_points.size()):
		var point = baked_points[i]
		var current_offset = original_curve.get_closest_offset(point)
		
		if current_offset <= split_offset:
			curve1.add_point(point)
		else:
			if not split_reached:
				# Add the exact split point to both curves to ensure continuity
				var exact_split_pos = original_curve.sample_baked(split_offset, false)
				curve1.add_point(exact_split_pos)
				curve2.add_point(exact_split_pos)
				split_reached = true
				
			curve2.add_point(point)
			
	return [curve1, curve2]

static func get_reversed_direction(curr_dir: Enums.PathDirection) -> Enums.PathDirection:
	if curr_dir == Enums.PathDirection.TRACK_NODES_INCREASE:
		return Enums.PathDirection.TRACK_NODES_INCREASE
	elif curr_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		return Enums.PathDirection.TRACK_NODES_INCREASE
	else: return Enums.PathDirection.STOP

static func get_dir_enum_name(dir_enum: Enums.PathDirection) -> String:
	if dir_enum == Enums.PathDirection.TRACK_NODES_INCREASE: return "forwards"
	elif dir_enum == Enums.PathDirection.TRACK_NODES_DECREASE: return "backwards"
	else: return "stopped"

static func reverse_curve3d(original_curve: Curve3D) -> Curve3D:
	var reversed_curve = Curve3D.new()
	var point_count = original_curve.point_count
	
	# Iterate through the original points backwards
	for i in range(point_count - 1, -1, -1):
		var position = original_curve.get_point_position(i)
		var in_tangent = original_curve.get_point_in(i)
		var out_tangent = original_curve.get_point_out(i)
		
		# Swapping in/out tangents reverses the curve's direction at that point
		reversed_curve.add_point(position, out_tangent, in_tangent)
		
	reversed_curve.up_vector_enabled = original_curve.up_vector_enabled
	return reversed_curve
