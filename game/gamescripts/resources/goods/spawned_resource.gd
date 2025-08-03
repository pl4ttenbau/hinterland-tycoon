class_name SpawnedResource extends GameObject

@export var res_type: BaseResourceType
@export var amount: int = 1
@export var current_location: ResourceContainer

func _init(_type: StringName) -> void:
	super(Enums.EntityTypes.GOOD)
	self.res_type = BaseResourceType.get_by_key(_type)
