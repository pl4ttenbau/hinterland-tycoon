class_name SpawnedResource extends GameObject

@export var res_type: BaseResourceType
@export var amount: int = 1

# can be stored in any resource container class
@export var current_location: ResourceContainer
	
# but only be targeted to a residential or industry structure
@export var target_location: BaseStructure

func _init(_type: StringName) -> void:
	super(Enums.EntityTypes.GOOD)
	self.res_type = BaseResourceType.get_by_key(_type)

func move_res_to(target_container: ResourceContainer):
	if self.current_location != null:
		self.current_location.remove_resource(self)
	target_container.add_resource(self)
