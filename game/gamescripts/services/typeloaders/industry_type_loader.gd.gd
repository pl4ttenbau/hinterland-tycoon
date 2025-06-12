class_name IndustryTypeLoader extends Node

func _init() -> void:
	self.make_types()
	
func make_types() -> Array[IndustryType]:
	var industry_types: Array[IndustryType] = [
		# producers
		IndustryType.new("FARM", "Farm", 8, [], ["4xgrains"]),
		IndustryType.new("COAL_MINE", "Coal Mine", 20, [], ["4xcoal"]),
		IndustryType.new("ICON_MINE", "Coal Mine", 30, [], ["6xiron"]),
		IndustryType.new("QUARRY", "Quarry", 12, [], ["8xstone"]),
		IndustryType.new("FISHERY", "Fishery", 9, [], ["5xfish"]),
		# transformers
		IndustryType.new("SMELTER", "Smelter", 22, ["3xiron", "3xcoal"], ["3xsteel"]),
		IndustryType.new("BAKERY", "Bakery", 5, ["5xgrains"], ["5xfood"]),
		IndustryType.new("BUTCHER", "Butcher", 9, ["3xfish"], ["3xmeat"]),
		# consumers
		IndustryType.new("COAL_PLANT", "Coal Plant", 20, ["4xcoal"], []),
	]
	GameTypes.industry_types = industry_types
	return industry_types
