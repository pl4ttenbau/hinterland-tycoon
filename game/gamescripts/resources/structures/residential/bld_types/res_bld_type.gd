@icon("res://assets/icons/icon_house_white.png")
class_name ResBldType extends AbstractBldType

@export var res_bld_cat: String
@export var pops: Array[int]
@export var block_auto_placement: bool = false
## Empty means unclassified. A model can belong to several regional themes.
@export var themes: Array[Enums.Location] = []

const STRUCTURES_FOLDER = "res://assets/meshes/structures/"

func _init(_key: String, _name: String, _popsInt: int, _block_auto_creation = false):
	super(_key, _name)
	@warning_ignore("integer_division")
	self.pops = [_popsInt, roundi(_popsInt / 3)]
	self.scene_path = self.get_scene_path()
	if _block_auto_creation:
		self.block_auto_placement = _block_auto_creation

#region Getters
## Catalogs can specify a scene independently of the residence key.
func get_scene_path() -> String:
	if not self.scene_path.is_empty():
		return self.scene_path
	return STRUCTURES_FOLDER + self.key + "/" + self.key + ".tscn"
	
static func get_by_key(_key: String) -> ResBldType:
	return GameTypes.res_bld_type_store.get_by_key(_key)
#endregion
