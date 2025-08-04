@icon("res://assets/icons/icon_house_white.png")
class_name ResBldType extends AbstractBldType

@export var res_bld_cat: String
@export var pops: Array[int]

const STRUCTURES_FOLDER = "res://assets/meshes/structures/"

func _init(_key: String, _name: String, _popsInt: int):
	super(_key, _name)
	self.pops = [_popsInt, roundi(_popsInt / 3)]
	self.scene_path = self.get_scene_path()

## <folder>/house_name/house_name.tscn
func get_scene_path() -> String:
	return STRUCTURES_FOLDER + self.key + "/" + self.key + ".tscn"
