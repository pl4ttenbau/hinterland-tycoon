@icon("res://assets/icons/icon_rail_track_white.png")
class_name InfrUtils extends Node

static func nothing():
	pass

static func smooth_curve3d(curve: Curve3D):
	var corner_speed: float = 2
	for idx in range(curve.point_count):
		# curve.add_point(curve.points[idx])
		if idx > 0:
			var delta = curve.get_point_position(idx) - curve.get_point_position(idx-1)
			delta /= corner_speed
			var normalized = delta.normalized() *2
			curve.set_point_in(idx, -normalized)
			curve.set_point_out(idx, +normalized)

static func infr_domain_str_2_enum(infr_domain_str: String) -> Enums.InfrDomain:
	if infr_domain_str == "RAIL": return Enums.InfrDomain.RAIL
	elif infr_domain_str == "ROAD": return Enums.InfrDomain.ROAD
	elif infr_domain_str == "WATER": return Enums.InfrDomain.WATER
	elif infr_domain_str == "AIR": return Enums.InfrDomain.AIR
	else: return Enums.InfrDomain.STATIONARY
