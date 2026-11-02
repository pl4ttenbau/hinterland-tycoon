@tool
class_name InfrLineValidator extends RefCounted

## returns validation error string, or "" when no problem
static func validate_records(json_records: Variant) -> String:
	if not json_records is Array:
		return "Expected an array of infrastructure records."
	var ids: Dictionary = {}
	for record: Variant in json_records:
		var problem: String = _validate_single_record(record, ids)
		if not problem.is_empty():
			return problem
	return ""

static func _validate_single_record(record: Variant, ids: Dictionary) -> String:
	if not record is Dictionary or not record.get("num") is float and not record.get("num") is int:
		return "Every record needs a numeric num."
	var num: float = record.num
	if not is_finite(num) or num < 0 or num != floor(num) or ids.has(int(num)):
		return "Record numbers must be unique nonnegative integers."
	ids[int(num)] = true
	for key: String in ["name", "type"]:
		if record.has(key) and not record[key] is String:
			return "Record %d has an invalid %s." % [int(num), key]
	if record.has("autosmooth") and not record.autosmooth is bool:
		return "Record %d has an invalid autosmooth setting." % int(num)
	if not record.get("points") is Array or record.points.size() < 2:
		return "Record %d needs at least two points." % int(num)
	for point: Variant in record.points:
		var problem: String = _validate_single_point(point, int(num))
		if not problem.is_empty():
			return problem
	return ""

static func _validate_single_point(point: Variant, record_num: int) -> String:
	if not point is Dictionary or not valid_vector(point.get("pos")):
		return "Record %d has an invalid point position." % record_num
	if point.has("cross"):
		if not point.cross is Dictionary:
			return "Record %d has invalid crossing metadata." % record_num
		for key: String in ["connectiveRoads", "autoConnectiveRoads"]:
			if point.cross.has(key):
				if not point.cross[key] is Array:
					return "Record %d has an invalid %s list." % [record_num, key]
				for id: Variant in point.cross[key]:
					if not (id is float or id is int) or not is_finite(float(id)) or float(id) < 0 or float(id) != floor(float(id)):
						return "Record %d has an invalid crossing road ID." % record_num
	for key: String in ["handleIn", "handleOut"]:
		if point.has(key) and not valid_vector(point[key]):
			return "Record %d has an invalid %s." % [record_num, key]
	return ""

static func valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for number: Variant in value:
		if not (number is float or number is int) or not is_finite(float(number)):
			return false
	return true
