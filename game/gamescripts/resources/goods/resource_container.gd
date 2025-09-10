class_name ResourceContainer extends GameObject

signal resource_change()

@export var resources: Array[SpawnedResource] = []

func add_resource_of(res_type_key: StringName) -> SpawnedResource:
	var spawned_res := SpawnedResource.new(res_type_key)
	self.add_resource(spawned_res)
	return spawned_res
	
func add_resource(spawned_res: SpawnedResource):
	self.resources.append(spawned_res)
	spawned_res.current_location = self
	self.resource_change.emit()

func remove_resource(spawned_res: SpawnedResource):
	self.resources.erase(spawned_res)
	self.resource_change.emit()
