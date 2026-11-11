class_name InfrType extends Resource

const GAUGE_1067_MM: String = "1067_MM"

## Keep 1,067 mm tracks and vehicles separate from the legacy rail network.
static func rail_gauges_compatible(first: String, second: String) -> bool:
	return first == second or (first != GAUGE_1067_MM and second != GAUGE_1067_MM)

@export var num: int
@export var is_rail: bool
@export var key: String
@export var template_scene_path: String

func _init(_num: int, _key: String, _is_rail: bool, _scene_path: String) -> void:
	self.num = _num
	self.is_rail = _is_rail
	self.key = _key
	self.template_scene_path = _scene_path
