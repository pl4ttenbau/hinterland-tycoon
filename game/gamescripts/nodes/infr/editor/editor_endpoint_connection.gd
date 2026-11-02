@tool
class_name EditorEndpointConnection extends Resource

## A derived connection target. Typed properties let the Inspector name the end.
@export var road: int = -1
@export var endpoint: Enums.EnumStartOrEnd = Enums.EnumStartOrEnd.START

func _validate_property(property: Dictionary) -> void:
	if property.name in ["road", "endpoint"]:
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY

static func of(road_num: int, road_end: int) -> EditorEndpointConnection:
	var connection := EditorEndpointConnection.new()
	connection.road = road_num
	connection.endpoint = road_end as Enums.EnumStartOrEnd
	return connection
