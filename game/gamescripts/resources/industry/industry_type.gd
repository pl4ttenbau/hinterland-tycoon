class_name IndustryType extends Resource

@export var key: String
@export var name: String
@export var workers: int
@export var requires: Array[TransformedResource] = []
@export var produces: Array[TransformedResource] = []

func _init(_key: String, _name: String, mesh_name: String, _workers: int, 
		_requires_strs: Array[String], _produces_strs: Array[String]):
	self.key = _key
	self.name = _name
	self.workers = _workers
	for requires_str: String in _requires_strs:
		self.requires.append(TransformedResource.from_string(requires_str))
	for produces_str: String in _produces_strs:
		self.produces.append(TransformedResource.from_string(produces_str))
