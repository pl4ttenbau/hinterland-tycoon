@icon("res://assets/icons/icon_industry_white.png")
class_name IndustryData extends GameEntityData

@export var pos: Vector3
@export var ind_type: IndustryType
@export var ind_name: String
## Player-built mines draw from these shared deposit cells.
@export_storage var mine_reserves: Array[MineralReserve] = []

## Assigned from the town centers on this map when the industry is placed.
var closest_town: TownData

## Held weakly: the station's StationConnections owns the entry, and the entry
## holds this industry, so a strong reference would form a cycle.
var station_connection: StationIndustryConnection:
	set(value): _station_connection = weakref(value) if value != null else null
	get(): return _station_connection.get_ref() if _station_connection != null else null
var _station_connection: WeakRef = null
@export_storage var road_exit: RoadNode

static var _last_ind_num: int = 0

#region Scene Callbacks
func _init(_ind_type_str: String, _pos: Vector3, site_recipe: IndustryType = null):
	super(Enums.EntityTypes.INDUSTRY)
	self.ind_type = site_recipe if site_recipe != null else self._get_ind_type_by_str(_ind_type_str)
	if self.ind_type != null:
		self.ind_name = self.ind_type.name
	self.pos = _pos
	self._autoregister()

func _autoregister():
	# assign num when not done before
	if !self.num: 
		IndustryData._last_ind_num += 1
		self.num = IndustryData._last_ind_num
	# add to storage & global state
	Managers.industries.storage.add(self)
#endregion

func _get_ind_type_by_str(ind_type_key: String) -> IndustryType:
	return GameTypes.get_ind_type(ind_type_key)
	
static func get_by_num(ind_num: int) -> IndustryData:
	for industry: IndustryData in GlobalState.industries:
		if industry.num == ind_num: return industry
	return null

#region Mapping from other classes
static func from_dict(ind_data: Dictionary) -> IndustryData:
	var dict_num: int = ind_data.get("num", null)
	var dict_pos: Vector3 = arr_to_vec3(ind_data.get("pos"))
	var ind_obj := IndustryData.new(ind_data.get("industryType"), dict_pos)
	ind_obj.num = dict_num
	SignalBus.industry_loaded.emit(ind_obj)
	return ind_obj
	
static func from_placeholder(placeholder: IndustryPlaceholder) -> IndustryData:
	var ind_obj := IndustryData.new(placeholder.type_key, placeholder.global_position)
	if placeholder.ind_name:
		ind_obj.ind_name = placeholder.ind_name
	return ind_obj
#endregion

#region Getters
static func arr_to_vec3(float_arr: Array) -> Vector3:
	return Vector3(float_arr[0], float_arr[1], float_arr[2])
