class_name StationCollider extends ClickableCollider

@onready var outer_station: NodeStationLink3D = $"../.."

func get_station() -> NodeStationLinkData:
	return outer_station.entity

func get_click_ref() -> ClickRef:
	return ClickRef.new(Enums.EntityTypes.STATION, self.get_station().num)
