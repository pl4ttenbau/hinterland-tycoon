@icon("res://assets/icons/icon_house_white.png")
class_name AbstractBldType extends Resource

@export var key: String
@export var name: String
@export var scene_path: String

func _init(_key: String, _name: String) -> void:
	self.key = _key
	self.name = _name
