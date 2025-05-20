extends Node
class_name Residence

@export var parent: BaseStructure
@export var pops: int = 2
@export var level: int = 1

static func of(_parent: BaseStructure, _pops: int):
	var instance: Residence = Residence.new()
	instance.parent = _parent
	instance.pops = _pops
	return instance
