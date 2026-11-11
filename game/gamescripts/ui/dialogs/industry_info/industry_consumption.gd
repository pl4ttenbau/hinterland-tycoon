class_name IndustryConsumption extends MarginContainer

func show_recipe(recipe: IndustryType, inventory: GoodsInventory) -> void:
	InventoryPresentation.fill_recipe_list(%GoodsTable, recipe.requires, inventory, true)
