class_name ResidenceBuildingData extends GameObject

@export var town_num: int
@export var bld_type: ResBldType
@export_storage var is_registered: bool = false

func _init(_town_num: int, _bld_type: ResBldType):
	super(Enums.EntityTypes.RESIDENCIAL)
	self.town_num = _town_num
	self.bld_type = _bld_type
	# generate new bld num
	self.num = OuterResBld.last_bld_num
	OuterResBld.last_bld_num += 1
	# register in globals
	GlobalState.res_blds.append(self)
