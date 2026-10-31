class_name AbstractGameTypeLoader extends RefCounted

signal loading_finished()

## Load and register definitions explicitly; constructing a loader has no side effects.
func load_types() -> Error:
	push_error("Type loaders must implement load_types()")
	return ERR_UNAVAILABLE

## Check before registering so duplicate keys cannot silently overwrite definitions.
static func validate_keys(types: Array) -> Error:
	if types.is_empty():
		push_error("Type catalog is empty")
		return ERR_INVALID_DATA
	var seen: Dictionary = {}
	for definition: Resource in types:
		if definition == null or definition.key.is_empty() or seen.has(definition.key):
			push_error("Type catalog contains a null definition, empty key, or duplicate key")
			return ERR_INVALID_DATA
		seen[definition.key] = true
	return OK
