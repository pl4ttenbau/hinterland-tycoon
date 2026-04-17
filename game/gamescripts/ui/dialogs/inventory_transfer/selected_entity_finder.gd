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

func _find_player() -> PlayerHead:
	return GlobalState.player

func _find_station() -> NodeStationLink3D:
	if !GlobalState.player.in_station:
		Loggie.warn("Cannot show current player station: player too far away from any")
		return null
	# find nearest to player:
	var parent_station: RailStationData = GlobalState.player.in_station
	var closest_node_st_data: NodeStationLinkData = self._find_closest_node_station(parent_station)
	return closest_node_st_data.station3d

func _find_closest_node_station(parent_station_obj: RailStationData) -> NodeStationLinkData:
	var nearest_to_player_dist: float = 9999.9
	var nearest_to_player_node_st_obj: NodeStationLinkData
	for node_station_obj: NodeStationLinkData in parent_station_obj.node_stations:
		var dist_to_player_sq: float = node_station_obj.position.distance_squared_to(GlobalState.player.get_pos())
		if dist_to_player_sq < nearest_to_player_dist:
			nearest_to_player_dist = dist_to_player_sq
			nearest_to_player_node_st_obj = node_station_obj
	return nearest_to_player_node_st_obj

func _find_train() -> Train3D:
	if !GlobalState.player.in_train:
		Loggie.warn("Cannot show current player train: player hasnt entered any")
		return null
	return GlobalState.player.in_train
