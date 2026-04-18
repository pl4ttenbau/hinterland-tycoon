class_name GoodsAmount extends RefCounted

@export_storage var res_key: String

@export_storage var amount: float

func _init(_res_key: String, _amount: float) -> void:
	self.res_key = _res_key
	self.amount = _amount

static func of_spawned(spawned_good: SpawnedGood) -> GoodsAmount:
	return GoodsAmount.new(spawned_good.res_type.key, spawned_good.amount)

static func of_transfer(transfer_dto: GoodsTransfer) -> GoodsAmount:
	return GoodsAmount.new(transfer_dto.res_key, transfer_dto.amount)
