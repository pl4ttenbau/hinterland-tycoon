class_name IndustryTypeLoader extends Node

func _init() -> void:
	self.make_types()
	
func make_types() -> Array[IndustryType]:
	var industry_types: Array[IndustryType] = [
		# producers
		IndustryType.new("FARM", "Farm", "windmill", 8, [], ["4xgrains"]),
		IndustryType.new("COAL_MINE", "Coal Mine", "mineshaft", 20, [], ["4xcoal"]),
		IndustryType.new("IRON_MINE","Iron Mine", "mineshaft", 30, [], ["6xiron"]),
		IndustryType.new("QUARRY", "Quarry", "mineshaft", 12, [], ["8xstone"]),
		IndustryType.new("FISHERY", "Fishery", "warehouse_1",  9, [], ["5xfish"]),
		IndustryType.new("FOREST", "Forest", "warehouse_1", 9, [], ["10xwood"]),
		# transformers
		IndustryType.new("SMELTER", "Smelter", "generic_small", 22, ["3xiron", "3xcoal"], ["3xsteel"]),
		IndustryType.new("SAWMILL", "Sawmill", "warehouse_1", 12, ["9xwood"], ["3xboards"]),
		IndustryType.new("BAKERY", "Bakery", "generic_small", 5, ["5xgrains"], ["5xfood"]),
		IndustryType.new("BUTCHER", "Butcher", "warehouse_1", 9, ["3xfish"], ["3xmeat"]),
		# consumers
		IndustryType.new("COAL_PLANT", "Coal Plant", "generic_small", 20, ["4xcoal"], []),
	]
	GameTypes.industry_types = industry_types
	return industry_types
