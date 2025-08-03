class_name ResourceContainer extends GameObject

@export var resources: Array[SpawnedResource] = []

func add_resource(res_type_key: StringName) -> SpawnedResource:
	var spawned_res: SpawnedResource = SpawnedResource.new(res_type_key)
	spawned_res.current_location = self
	return spawned_res
