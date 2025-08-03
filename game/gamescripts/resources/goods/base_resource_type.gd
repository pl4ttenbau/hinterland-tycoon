@icon("res://assets/icons/icon_good_white.png")
class_name BaseResourceType extends Resource

enum ResourceCategory {PASSENGER, MAIL, FREIGHT}

@export var key: StringName
@export var res_cat: ResourceCategory

func _init(_key: StringName, _cat: BaseResourceType.ResourceCategory):
	self.key = _key
	self.res_cat = _cat

static func get_by_key(_key: StringName) -> BaseResourceType:
	var found := GameTypes.resource_types.get(_key) as BaseResourceType
	if ! found:
		Loggie.warn("cannot get resource type \"%s\"" % _key)
		return null
	return found
