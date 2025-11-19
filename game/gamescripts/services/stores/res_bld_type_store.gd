class_name ResBldTypeStore extends Resource

@export var _list: Array[ResBldType] = []
@export var _by_key: Dictionary = {}

func _init():
	GameTypes.res_bld_store = self

func add(res_bld_type: ResBldType):
	self._list.append(res_bld_type)
	self._by_key.set(res_bld_type.key, res_bld_type)
	GameTypes.res_bld_types.append(res_bld_type)

func get_all() -> Array[ResBldType]:
	return self._list
	
func get_by_key(key: String) -> ResBldType:
	var found: ResBldType = self._by_key.get(key)
	if ! found: Loggie.error("Cannot find ResidencialBldType \"%s\"" % key)
	return found
	
func get_random() -> ResBldType:
	randomize()
	var rnd_i: int = randi_range(0, self.get_all().size() -1)
	return self._list.get(rnd_i)

func is_empty() -> bool: 
	return self._list.size() >= 1
