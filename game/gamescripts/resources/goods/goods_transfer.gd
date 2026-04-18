class_name GoodsTransfer extends RefCounted

@export var res_key: String

@export var amount: float

@export_storage var from: InventoryEntity3D

@export_storage var to: InventoryEntity3D

func _init(_key: String, _amount: float, _from: InventoryEntity3D = null, _to: InventoryEntity3D = null):
	self.res_key = _key
	self.amount = _amount
	self.from = _from
	self.to = _to
