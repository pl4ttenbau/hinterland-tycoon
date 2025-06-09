class_name IndustryTypeLoader extends Node

func _init() -> void:
	self.make_types()
	
func make_types() -> Array[IndustryType]:
	var industry_types: Array[IndustryType] = [
		# producers
		IndustryType.new("farm", "Farm", 8, [], ["4xgrains"]),
		IndustryType.new("coal_mine", "Coal Mine", 20, [], ["4xcoal"]),
		IndustryType.new("iron_mine", "Coal Mine", 30, [], ["6xiron"]),
		IndustryType.new("quarry", "Quarry", 12, [], ["8xstone"]),
		IndustryType.new("fishery", "Fishery", 9, [], ["5xfish"]),
		# transformers
		IndustryType.new("smelter", "Smelter", 22, ["3xiron", "3xcoal"], ["3xsteel"]),
		IndustryType.new("bakery", "Bakery", 5, ["5xgrains"], ["5xfood"]),
		IndustryType.new("slaughterhouse", "Butcher", 9, ["3xfish"], ["3xmeat"]),
		# consumers
		IndustryType.new("coal_plant", "Coal Plant", 20, ["4xcoal"], []),
	]
	GameTypes.industry_types = industry_types
	return industry_types
