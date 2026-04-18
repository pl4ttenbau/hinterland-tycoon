@icon("res://assets/icons/icon_house.png")
class_name Residence3D extends GameEntity3D

static var last_bld_num: int = 0

@export_storage var num: int:
	get(): 
		if self.entity:
			return self.entity.num
		return -1
	set(value): 
		if self.entity:
			self.entity.num = value

@export_storage var res_bld_obj: ResidenceBuildingData:
	get: return self.entity as ResidenceBuildingData
	set(value): self.entity = value

@export_storage var connected_station: NodeStationLinkData:
	get(): return self.res_bld_obj.connected_station

## when its spawned from map
@export var placed_res_bld_type: String
@export var placed_town_num: int

#region Static Getters
static func get_random() -> Residence3D:
	return GlobalState.res_bld_containers.pick_random() as Residence3D
#endregion

static func next_num() -> int:
	Residence3D.last_bld_num += 1
	return Residence3D.last_bld_num
