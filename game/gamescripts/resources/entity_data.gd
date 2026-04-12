class_name GameEntityData extends Resource

@export var num: int

@export_storage var type: Enums.EntityTypes

func _init(_type: Enums.EntityTypes):
	self.type = _type
