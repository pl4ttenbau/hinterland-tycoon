class_name InventoryCategoryTabs extends CategoryTabs

func _ready() -> void:
	super._ready()
	add_tab("Passengers", InventoryPresentation.icon(&"passenger"), "By interchange")
	add_tab("Cargo", preload("res://assets/ui/images/goods_type/box_storage.png"), "Materials and goods")
