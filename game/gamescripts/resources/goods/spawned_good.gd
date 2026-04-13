# an amount of goods thats either waiting or during transportation
class_name SpawnedGood extends GameEntityData

@export var is_valid: bool = true

@export var res_type: BaseGoodsType
@export var amount: float = 1

# can be stored in any resource container class
@export var current_location: GoodsInventory

# but only be targeted to a residential or industry structure
@export var target_location: AbstractStructure

func _init(_res_type: StringName, _amount: float, _target: AbstractStructure = null) -> void:
	super(Enums.EntityTypes.GOOD)
	self.res_type = BaseGoodsType.get_by_key(_res_type)
	self._check_goods_type(_res_type)
	self.target_location = _target

func move_res_to(target_container: GoodsInventory):
	if self.current_location != null:
		self.current_location.remove_spawned_good(self)
	target_container.add_spawned_good(self)

func _check_goods_type(_res_type):
	if !self.res_type:
		Loggie.warn("Cannot find goods type %s" % _res_type)
		self.is_valid = false
