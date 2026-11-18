## Rail platforms use their existing collider. Road shelters put this collider
## on layer 20 for mouse rays so it does not obstruct vehicles or the player.
class_name StationCollider extends ClickableCollider

## The rail platform and either side of a road shelter resolve to the stop data.
func get_stop() -> AbstractStation:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is NodeStationLink3D:
			return ancestor.node_station.parent_station if ancestor.node_station != null else null
		if ancestor is BusStop3D:
			return ancestor.station
		ancestor = ancestor.get_parent()
	return null

func get_click_ref() -> ClickRef:
	var stop: AbstractStation = get_stop()
	return ClickRef.new(Enums.EntityTypes.STATION, stop.num) if stop != null else null
