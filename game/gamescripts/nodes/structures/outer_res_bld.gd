@icon("res://assets/icons/icon_house.png")
class_name OuterResBld extends HideableObject

static var last_bld_num: int = 0

@export_storage var num: int:
	get: return self.entity.num
	set(value): self.entity.num = value
		
@export_storage var res_bld: ResidenceBuildingData:
	get: return self.entity as ResidenceBuildingData
	set(value): self.entity = value

## when its spawned from map
@export var placed_res_bld_type: String
@export var placed_town_num: int

static func next_num() -> int:
	OuterResBld.last_bld_num += 1
	return OuterResBld.last_bld_num
