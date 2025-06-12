class_name TransformedResource extends Resource

@export var res_key: String
@export var res_modifier: float

func _init(_key: String, _modifier: float):
	self.res_key = _key
	self.res_modifier = _modifier
	
func _to_string() -> String:
	return "<TransformedResource::%s %f>" % [self.res_key, self.res_modifier]

static func from_string(_str: String) -> TransformedResource:
	var splitted: PackedStringArray = _str.split("x")
	var res_key: String = splitted.get(1)
	var res_modifier: float = splitted.get(0).to_float()
	return TransformedResource.new(res_key, res_modifier)
