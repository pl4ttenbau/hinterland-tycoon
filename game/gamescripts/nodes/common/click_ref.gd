class_name ClickRef extends Resource

@export var entity_type: Enums.EntityTypes
@export var entity_num: int

func _init(_type: Enums.EntityTypes, _num: int):
	self.entity_type = _type
	self.entity_num = _num

func get_type_str() -> String:
	return Enums.EntityTypes.keys()[self.entity_type]
