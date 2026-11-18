## Inspection details for the current rail draft, in metres and whole DM.
class_name RailConstructionQuote extends RefCounted

var length_metres: float
var gauge_mm: int
var price: int

func _init(length: float, gauge: int, cost: int) -> void:
	length_metres = length
	gauge_mm = gauge
	price = cost
