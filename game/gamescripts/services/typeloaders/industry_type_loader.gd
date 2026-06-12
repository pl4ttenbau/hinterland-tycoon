class_name IndustryTypeLoader extends AbstractGameTypeLoader

func _init() -> void:
	self.make_types()
	
func make_types() -> Array[IndustryType]:
	var industry_types: Array[IndustryType] = [
		# producers: food
		IndustryType.new("FARM", "Farm", "windmill_2", 8, [], ["4xgrains", "2xbeets"]),
		IndustryType.new("RANCH", "Ranch", "windmill_2", 8, [], ["3xmeat"]),
		IndustryType.new("FISHERY", "Fishery", "wooden_storehouse",  9, [], ["5xfish"]),
		# producers: aggregates
		IndustryType.new("COAL_MINE", "Coal Mine", "mineshaft", 20, [], ["4xcoal"]),
		IndustryType.new("IRON_MINE","Iron Mine", "mineshaft", 30, [], ["6xore"]),
		IndustryType.new("QUARRY", "Quarry", "mineshaft", 12, [], ["8xstone", "3xgravel"]),
		IndustryType.new("FOREST", "Forest", "warehouse_1", 9, [], ["10xlumber"]),
		IndustryType.new("CHARCOAL_BURNER", "Charcoal Burner", "warehouse_1", 15, ["3xlumber"], ["2xcoal"]),
		# producers: liquid
		IndustryType.new("OIL_WELL", "Oil Well", "oil_derrick", 15, [], ["9xoil"]),
		# transformers: food
		IndustryType.new("SUGAR_MILL", "Sugar Mill", "factory_small", 9, ["6xbeets"], ["3xsugar"]),
		IndustryType.new("BREWERY", "Brewery", "factory_small", 9, ["6xgrains", "2xsugar"], ["3xalcohol"]),
		IndustryType.new("BAKERY", "Bakery", "restaurant", 5, ["5xgrains", "1xsugar"], ["2xbread"]),
		IndustryType.new("BUTCHER", "Butcher", "warehouse_1", 9, ["3xfish"], ["3xmeat"]),
		# transformers: aggregates
		IndustryType.new("SMELTER", "Smelter", "factory_small", 22, ["3xore", "3xcoal"], ["3xingots"]),
		IndustryType.new("SAWMILL", "Sawmill", "warehouse_1", 12, ["9xlumber"], ["3xboards"]),
		IndustryType.new("BRICKWORKS", "Brickworks", "factory_small", 12, ["5xgravel"], ["2xbricks"]),
		IndustryType.new("PAPER_MILL", "Paper Mill", "warehouse_1", 12, ["6xlumber", "2xchemicals"], ["2xpaper"]),
		IndustryType.new("FERTILIZER_FACTORY", "Fertilizer Factory", "oil_derrick", 12, ["2xchemicals", "5xbeets"], ["2xfertilizer"]),
		# transformers: smithing
		IndustryType.new("SMITHY", "Smithy", "factory_small", 12, ["2xingots", "1xcoal", "2xlumber"], ["2xtools", "1xrail_tracks"]),
		IndustryType.new("WORKSHOP", "Workshop", "factory_small", 12, ["3xingots", "2xcoal"], ["1xweapons", "1xmachines"]),
		# transformers: liquid
		IndustryType.new("OIL_REFINERY", "Refinery", "oil_derrick", 12, ["6xoil"], ["4xchemicals"]),
		# consumers
		IndustryType.new("COAL_PLANT", "Coal Plant", "factory_small", 25, ["4xcoal"], []),
		IndustryType.new("SMALL_STORE", "Small Store", "wooden_storehouse", 10, ["2xbread", "2xmeat", "1xalcohol"], []),
		IndustryType.new("BIG_STORE", "Big Store", "warehouse_1", 20, ["4xcoal"], []),
		IndustryType.new("RESTAURANT", "Restaurant", "restaurant", 12, ["2xalcohol", "1xbread", "2xfish"], []),
		IndustryType.new("BARRACKS", "Barracks", "warehouse_1", 25, ["3xalcohol", "2xmeat", "1xweapons"], ["2xsoldier"])
	]
	GameTypes.industry_types = industry_types
	return industry_types
