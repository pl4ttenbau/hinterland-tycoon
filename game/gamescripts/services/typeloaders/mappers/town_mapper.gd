@tool
class_name TownMapper extends RefCounted

static func town_list_from_dict_arr(town_data_arr: Array) -> Array[TownData]:
	var town_obj_arr: Array[TownData] = []
	for town_values_dict: Dictionary in town_data_arr:
		town_obj_arr.append(TownMapper.town_dict_2_obj(town_values_dict))
	return town_obj_arr

static func town_dict_2_obj(town_dict: Dictionary) -> TownData:
	var townPosArr = town_dict["pos"] as Array
	if ! townPosArr:
		push_warning("Town %s has no known position" % town_dict["name"])
		return null
	else:	
		var dict_town_name: String = town_dict["name"]
		var posXZ: Vector2 = Vector2(float(townPosArr[0]), float(townPosArr[1]))
		var pops = null
		var dict_is_minor: bool = town_dict.get("isMinor", false)
		var dict_autogenerate_houses: bool = town_dict.get("autogenerateHouses", true)
		return TownData.of(dict_town_name, posXZ, pops, dict_is_minor, dict_autogenerate_houses)
