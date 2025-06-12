class_name ResBldType extends Resource

@export var key: String
@export var name: String
@export var scene_path: String
@export var res_bld_cat: String
@export var pops: Array[int]

const STRUCTURES_FOLDER = "res://assets/meshes/structures/"

func _init(_key: String, _name: String, _popsInt: int):
	self.key = _key
	self.name = _name
	self.pops = [_popsInt, roundi(_popsInt / 3)]
	self.scene_path = self.get_scene_path()

func get_scene_path() -> String:
	return STRUCTURES_FOLDER + self.key + "/" + self.key + ".tscn"
