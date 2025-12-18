@tool
class_name VehicleMapper extends RefCounted

static func type_dict_to_class(_dict: Dictionary) -> RailVehicleType:
	var inst := RailVehicleType.of_key(_dict.get("key"))
	inst.display_name = _dict.get("name")
	inst.scene_path = _dict.get("scene_path")
	inst.max_speed_kmh = _dict.get("max_speed_kmh")
	if _dict.has("has_motor") && _dict.get("has_motor") == true:
		inst.has_motor = true
	# usable infr
	if _dict.has("usable_infr"):
		inst.usable_infr = UsableInfrType.of_dict(_dict.get("usable_infr"))
	# goods capacity
	if _dict.has("capacity"):
		inst.capacity = GoodsCapacity.of_json(_dict.get("capacity"))
	return inst
