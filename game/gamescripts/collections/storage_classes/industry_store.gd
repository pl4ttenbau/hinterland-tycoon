@icon("res://assets/icons/icon_industry_white.png")
class_name IndustryStore extends Resource

@export var _list: Array[IndustryData] = []
@export var _by_id: Dictionary = {}

@export_storage var _containers: Array[Industry3D] = []
@export_storage var _containers_by_id: Dictionary = {}

signal industry_added(ind_obj: IndustryData)
	
func _enter_tree() -> void:
	self.industry_added.connect(Callable(self, "_on_industry_loaded"))

#region Add Industry
func add(ind_obj: IndustryData):
	self._list.append(ind_obj)
	self._create_indexes(ind_obj)
	self.industry_added.emit(ind_obj)
	# add to global state as well
	GlobalState.industries.append(ind_obj)
	
func add_container(outer_ind: Industry3D):
	self._containers.append(outer_ind)
	self._containers_by_id.set(outer_ind.industry.num, outer_ind)
	GlobalState.ind_bld_containers.append(outer_ind)
	
func _create_indexes(ind_obj: IndustryData):
	self._by_id.set(ind_obj.num, ind_obj)
#endregion

#region Get Rail industry
func get_all() -> Array[IndustryData]:
	return self._list

func get_by_num(ind_num: int) -> IndustryData:
	var found: IndustryData =  self._by_id.get(ind_num)
	if ! found: Loggie.error("Cannot get industry %d; out of index?" % ind_num)
	return found
	
func get_containers() -> Array[Industry3D]:
	return self._containers
	
func get_container_by_num(ind_num: int) -> Industry3D:
	var found: Industry3D = self._containers_by_id.get(ind_num, null)
	if ! found: Loggie.error("Cannot get Industry3D %d; out of index?" % ind_num)
	return found
#endregion

#region Callbacks & Helpers 
func _on_industry_loaded(ind_obj: IndustryData):
	GlobalState.industries.append(ind_obj)
#endregion
