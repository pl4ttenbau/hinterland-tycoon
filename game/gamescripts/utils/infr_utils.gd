@icon("res://assets/icons/icon_rail_track_white.png")
class_name InfrUtils extends RefCounted

static func smooth_curve3d(curve: Curve3D):
	var corner_speed: float = 2
	for idx in range(curve.point_count):
		if idx > 0:
			if curve.get_point_in(idx) != Vector3.ZERO:
				continue
			# TODO: hier wird die Richtung zum vorigen Node genommen & normalisiert
			# besser wäre es, den Durchscnitt aus dieser und dem folgenden Node zu nehmen
			var delta = curve.get_point_position(idx) - curve.get_point_position(idx-1)
			delta /= corner_speed
			var normalized = delta.normalized() *2
			curve.set_point_in(idx, -normalized)
			curve.set_point_out(idx, +normalized)
			
static func get_aabb(vec_3_arr: Array[Vector3]) -> AABB:
	var min_pos: Vector3
	var max_pos: Vector3
	for point in vec_3_arr:
		# min pos
		if ! min_pos: min_pos = point
		elif point.x < min_pos.x: min_pos.x = point.x
		elif point.y < min_pos.y: min_pos.y = point.y
		elif point.z < min_pos.z: min_pos.z = point.z
		# max pos
		if ! max_pos: max_pos = point
		elif point.x > max_pos.x: max_pos.x = point.x
		elif point.y > max_pos.y: max_pos.y = point.y
		elif point.z > max_pos.z: max_pos.z = point.z
	var aabb = AABB(min_pos, Vector3.ZERO)
	aabb.end = max_pos
	return aabb

static func infr_domain_str_2_enum(infr_domain_str: String) -> Enums.InfrDomain:
	if infr_domain_str == "RAIL": return Enums.InfrDomain.RAIL
	elif infr_domain_str == "ROAD": return Enums.InfrDomain.ROAD
	elif infr_domain_str == "WATER": return Enums.InfrDomain.WATER
	elif infr_domain_str == "AIR": return Enums.InfrDomain.AIR
	else: return Enums.InfrDomain.STATIONARY
