class_name EntityUtils extends RefCounted

static func get_entity_type_enum_name(entity_type_enum: Enums.EntityTypes) -> String:
	match entity_type_enum:
		Enums.EntityTypes.PLAYER: return "Player"
		Enums.EntityTypes.VEHICLE: return "Vehicle"
		Enums.EntityTypes.TRAIN: return "Train"
		Enums.EntityTypes.RAIL: return "Rail"
		Enums.EntityTypes.ROAD: return "Road"
		Enums.EntityTypes.DEPOT: return "Depot"
		Enums.EntityTypes.NODE_STATION: return "Node Station"
		Enums.EntityTypes.STATION: return "Station"
		Enums.EntityTypes.TOWN: return "Town"
		Enums.EntityTypes.RESIDENCIAL: return "Residential"
		Enums.EntityTypes.INDUSTRY: return "Industry"
		Enums.EntityTypes.FORK: return "Fork"
		Enums.EntityTypes.GOOD: return "Good"
		Enums.EntityTypes.DECO_STATIC: return "Deco (Static)"
		Enums.EntityTypes.DECO_SPLINE: return "Deco (Spline)"
		_: return "unknown"
