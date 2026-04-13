## inventory as a node, that can be added to any InventoryEntityData-class
@icon("res://assets/icons/icon_good_white.png")
class_name InventoryContainer extends Node

@export var inventory: GoodsInventory

func _enter_tree() -> void:
	if !self.inventory:
		self.inventory = GoodsInventory.new()
