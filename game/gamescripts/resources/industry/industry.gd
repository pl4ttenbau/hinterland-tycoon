@icon("res://assets/icons/icon_industry_white.png")
class_name IndustryData extends GoodsInventory

@export var pos: Vector3
@export var ind_type: IndustryType

#region Scene Callbacks
func _init(_ind_type_str: String, _pos: Vector3):
	super(Enums.EntityTypes.INDUSTRY)
	self.ind_type = self._get_ind_type_by_str(_ind_type_str)
	self.pos = _pos
	self._autoregister()

func _autoregister():
	if !self.num: self.num = GlobalState.industries.size()
	GlobalState.industries.append(self)
#endregion

func _get_ind_type_by_str(ind_type_key: String) -> IndustryType:
	return GameTypes.get_ind_type(ind_type_key)

# == LOADING FROM JSON OR PLACEHOLDER ==
static func from_dict(ind_data: Dictionary) -> IndustryData:
	var dict_num: int = ind_data.get("num", null)
	var dict_pos: Vector3 = arr_to_vec3(ind_data.get("pos"))
	var ind_obj := IndustryData.new(ind_data.get("industryType"), dict_pos)
	ind_obj.num = dict_num
	SignalBus.industry_loaded.emit(ind_obj)
	return ind_obj
	
static func from_placeholder(placeholder: IndustryPlaceholder) -> IndustryData:
	var ind_obj := IndustryData.new(placeholder.type_key, placeholder.global_position)
	# ind_obj.num = placeholder.num
	return ind_obj

#region Getters
static func arr_to_vec3(float_arr: Array) -> Vector3:
	return Vector3(float_arr[0], float_arr[1], float_arr[2])
	
func has_required_goods() -> bool:
	for required_res: TransformedGood in self.ind_type.requires:
		@warning_ignore("narrowing_conversion")
		var spawned_good := SpawnedGood.new(required_res.res_key, required_res.res_modifier)
		if ! self.has_enough(spawned_good): return false
	return true

func get_produced_amount(good_type_key: String) -> int:
	for produced_good: TransformedGood in self.ind_type.produces:
		if produced_good.res_key == good_type_key:
			return produced_good.res_modifier as int
	return 0
