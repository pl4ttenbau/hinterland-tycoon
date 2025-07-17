class_name ResidenceBuildingData extends GameObject

@export var town_num: int
@export var bld_type: ResBldType

func _init(_bld_type: ResBldType):
	super(Enums.EntityTypes.RESIDENCIAL)
	# generate new bld num
	self.num = OuterResBld.last_bld_num
	OuterResBld.last_bld_num += 1
	# set bld entity
	self.bld_type = _bld_type
