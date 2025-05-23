class_name InfrType extends Resource

@export var num: int
@export var is_rail: bool
@export var key: String
@export var template_scene_path: String

func _init(_num: int, _key: String, _is_rail: bool, _scene_path: String) -> void:
	self.num = _num
	self.is_rail = _is_rail
	self.key = _key
	self.template_scene_path = _scene_path
