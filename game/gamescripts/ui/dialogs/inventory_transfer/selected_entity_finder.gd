@icon("res://assets/icons/icon_gears_white.png")
class_name SelectedEntityFinder extends Node

signal selected_entity_found(inv_entity: InventoryEntity3D)

func find_selected_entity_by_index(index: int):
	# only in game
	if Engine.is_editor_hint(): return
	# look for player, entered train or closest station InventoryEntity3D
	var found_entity: InventoryEntity3D = null
	if index == 0:
		found_entity = self._find_player()
	elif index == 1:
		found_entity = self._find_train()
	elif index == 2:
		found_entity = self._find_station()
	else:
		Loggie.info("Cannot find close entity of type with index %d" % index)
		return
	self.selected_entity_found.emit(found_entity)

func _find_player() -> PlayerHead3D:
	return GlobalState.player

func _find_station() -> RailStation3D:
	if !GlobalState.player.in_station:
		Loggie.warn("Cannot show current player station: player too far away from any")
		return null
	# find nearest to player:
	var parent_station: RailStationData = GlobalState.player.in_station
	var closest_station_3d: RailStation3D = self.find_closest_station_3d(parent_station)
	return closest_station_3d

func find_closest_station_3d(parent_station_obj: RailStationData) -> RailStation3D:
	var nearest_to_player_dist: float = 9999.9
	var nearest_to_player_node_st_obj: NodeStationLinkData
	for node_station_obj: NodeStationLinkData in parent_station_obj.node_stations:
		var dist_to_player_sq: float = node_station_obj.position.distance_squared_to(GlobalState.player.get_pos())
		if dist_to_player_sq < nearest_to_player_dist:
			nearest_to_player_dist = dist_to_player_sq
			nearest_to_player_node_st_obj = node_station_obj
	var station_num: int = nearest_to_player_node_st_obj.parent_station_num
	return Managers.stations.get_station_3d_with_num(station_num)

func _find_train() -> Train3D:
	if !GlobalState.player.in_train:
		Loggie.warn("Cannot show current player train: player hasnt entered any")
		return null
	return GlobalState.player.in_train
