@icon("res://assets/icons/icon_town_white.png")
class_name TownStore extends Resource

var SAVE_PATH_FORMAT = "res://world/%s/reslists/towns.dat"

@export var _list: Array[TownData] = []
@export var _by_id: Dictionary = {}
@export var _by_name: Dictionary = {}

@export_storage var _centers_list: Array[TownCenter] = []
@export var _centers_by_id: Dictionary = {}

signal town_added(town_obj: TownData)

@warning_ignore("unused_signal")
signal center_added(town_center: TownCenter)
	
func _enter_tree() -> void:
	self.town_added.connect(Callable(self, "_on_town_loaded"))

#region Add City
func add(town_obj: TownData):
	self._list.append(town_obj)
	self._create_indexes(town_obj)
	self.town_added.emit(town_obj)
	
func _create_indexes(town_obj: TownData):
	self._by_id.set(town_obj.num, town_obj)
	self._by_name.set(StringName(town_obj.town_name), town_obj)
	
func add_outter(town_center: TownCenter):
	self._centers_list.append(town_center)
	self._centers_by_id.set(town_center.town.num, town_center)
#endregion

#region Get City
func get_all() -> Array[TownData]:
	return self._list

func get_by_num(town_num: int) -> TownData:
	return self._by_id.get(town_num)
	
func get_by_name(town_name: StringName) -> TownData:
	return self._by_name.get(town_name)
	
func get_centers() -> Array[TownCenter]:
	return self._centers_list
	
func get_center_by_num(town_num: int) -> TownCenter:
	return self._centers_by_id.get(town_num)
#endregion

#region Callbacks & Helpers 
func _on_town_loaded(town_obj: TownData):
	GlobalState.towns.append(town_obj)
#endregion
