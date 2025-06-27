class_name StationCollider extends ClickableCollider

@onready var outer_station: OuterRailStation = self.get_parent_node_3d()

func get_station() -> RailStationData:
	return outer_station.entity

func get_click_ref() -> ClickRef:
	return ClickRef.new(Enums.EntityTypes.STATION, self.get_station().num)
