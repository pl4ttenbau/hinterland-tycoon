## One selectable inventory row. A destination is always a physical stop ID.
class_name InventoryStack extends RefCounted

var good_key: StringName
var amount: float
var destination_stop: int = -1

func _init(key: StringName = &"", quantity: float = 0, destination: int = -1) -> void:
	good_key = key
	amount = quantity
	destination_stop = destination

func identity() -> String:
	return "%s:%d" % [good_key, destination_stop]
