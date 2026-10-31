@tool
class_name VehicleMapper extends RefCounted

static func type_dict_to_class(data: Dictionary) -> VehicleTypeData:
	if not _is_valid(data):
		return null
	var definition := VehicleTypeData.new()
	_apply_fields(definition, data)
	return definition

static func rail_type_dict_to_class(data: Dictionary) -> RailVehicleTypeData:
	# The catalog implies the domain; keep it on runtime definitions for shared code.
	var rail_data: Dictionary = data.duplicate(true)
	var infrastructure: Variant = rail_data.get("usable_infr")
	if not infrastructure is Dictionary:
		push_error("Rail vehicle requires an infrastructure definition")
		return null
	if infrastructure.has("domain") and infrastructure["domain"] != "RAIL":
		push_error("Rail vehicle catalog contains a non-rail definition")
		return null
	infrastructure["domain"] = "RAIL"
	if not _is_valid(rail_data):
		return null
	var definition := RailVehicleTypeData.new()
	_apply_fields(definition, rail_data)
	return definition

static func _apply_fields(definition: VehicleTypeData, data: Dictionary) -> void:
	definition.key = data["key"]
	definition.display_name = data["display_name"]
	definition.model_scene_path = data["model_scene_path"]
	definition.max_speed_kmh = int(data["max_speed_kmh"])
	definition.has_motor = data["has_motor"]
	definition.length_metres = float(data["length_metres"])
	definition.mass_tonnes = float(data["mass_tonnes"]) if data.get("mass_tonnes") != null else null
	definition.motor_power_kw = float(data["motor_power_kw"]) if data.get("motor_power_kw") != null else null
	definition.usable_infr = UsableInfrType.of_dict(data["usable_infr"])
	if data.has("capacity"):
		definition.capacity = GoodsCapacity.of_json(data["capacity"])

static func _is_valid(data: Dictionary) -> bool:
	for field: String in ["key", "display_name", "model_scene_path"]:
		if not data.get(field) is String or data[field].is_empty():
			push_error("Vehicle definition requires a nonempty %s" % field)
			return false
	if not _is_number(data.get("max_speed_kmh")) or data["max_speed_kmh"] <= 0 \
			or int(data["max_speed_kmh"]) != data["max_speed_kmh"]:
		push_error("Vehicle %s requires a positive integer speed" % data["key"])
		return false
	if not _is_number(data.get("length_metres")) or data["length_metres"] <= 0:
		push_error("Vehicle %s requires a positive length" % data["key"])
		return false
	for field: String in ["mass_tonnes", "motor_power_kw"]:
		var value: Variant = data.get(field)
		if value != null and (not _is_number(value) or not is_finite(float(value)) \
				or value < 0 or (field == "mass_tonnes" and value == 0)):
			push_error("Vehicle %s has an invalid %s" % [data["key"], field])
			return false
	if not data.get("has_motor") is bool:
		return false
	var infrastructure: Variant = data.get("usable_infr")
	if not infrastructure is Dictionary or not infrastructure.get("domain") is String \
			or not Enums.InfrDomain.has(infrastructure["domain"]) \
			or not infrastructure.get("subtype", "") is String:
		push_error("Vehicle %s has an invalid infrastructure definition" % data["key"])
		return false
	if data.has("capacity"):
		var capacity: Variant = data["capacity"]
		if not capacity is Dictionary or not capacity.get("cat") is String \
				or not BaseGoodsType.ResourceCategory.has(capacity["cat"]) \
				or not _is_number(capacity.get("amount")) or capacity["amount"] < 0 \
				or int(capacity["amount"]) != capacity["amount"]:
			push_error("Vehicle %s has an invalid capacity" % data["key"])
			return false
	return true

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
