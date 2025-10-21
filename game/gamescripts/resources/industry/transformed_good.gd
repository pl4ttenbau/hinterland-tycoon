class_name TransformedGood extends Resource

@export var res_key: String
@export var res_modifier: float

func _init(_key: String, _modifier: float):
	self.res_key = _key
	self.res_modifier = _modifier
	
func _to_string() -> String:
	return "<TransformedGood::%s %f>" % [self.res_key, self.res_modifier]

static func from_string(_str: String) -> TransformedGood:
	var splitted: PackedStringArray = _str.split("x")
	return TransformedGood.new(splitted.get(1), splitted.get(0).to_float())
