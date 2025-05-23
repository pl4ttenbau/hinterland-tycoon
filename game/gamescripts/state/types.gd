extends Node

@export var infr_types: Array[InfrType] = InfrTypesLoader.make_types()

# == GETTER METHODS ==
func get_infr_type(key: String) -> InfrType:
	for infr_type: InfrType in self.infr_types:
		if infr_type.key == key: return infr_type
	push_error("InfrType %s could not be found" % key)
	return null
