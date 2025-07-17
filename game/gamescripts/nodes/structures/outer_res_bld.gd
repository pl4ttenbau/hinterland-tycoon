@icon("res://assets/icons/icon_house.png")
class_name OuterResBld extends HideableObject

static var last_bld_num: int = 0

@export var num: int:
	get: return self.entity.num
	set(value): self.entity.num = value
		
@export var res_bld: ResidenceBuildingData:
	get: return self.entity
	set(value): self.entity = value
