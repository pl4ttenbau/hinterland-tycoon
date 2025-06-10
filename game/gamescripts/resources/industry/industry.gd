@icon("res://assets/icons/icon_industry_white.png")
class_name Industry extends GameObject

@export var pos: Vector3
@export var ind_type: IndustryType

func _init(_ind_type_str: String, _pos: Vector3):
	super(Enums.EntityTypes.INDUSTRY)
	self.ind_type = self._get_ind_type_by_str(_ind_type_str)
	self.pos = _pos
	self._autoregister()

func _autoregister():
	if !self.num: self.num = GlobalState.industries.size()
	GlobalState.industries.append(self)

func _get_ind_type_by_str(ind_type_key: String) -> IndustryType:
	return GameTypes.get_ind_type(ind_type_key)

# == LOADING FROM JSON ==
static func from_dict(ind_data: Dictionary) -> Industry:
	var num: int = ind_data.get("num", null)
	var ind_type_key: String = ind_data.get("industryType")
	var pos: Vector3 = arr_to_vec3(ind_data.get("pos"))
	var ind_obj: Industry = Industry.new(ind_type_key, pos)
	ind_obj.num = num
	SignalBus.industry_loaded.emit(ind_obj)
	return ind_obj
	
static func arr_to_vec3(float_arr: Array) -> Vector3:
	return Vector3(float_arr[0], float_arr[1], float_arr[2])
	
