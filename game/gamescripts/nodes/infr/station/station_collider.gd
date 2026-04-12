class_name StationCollider extends ClickableCollider

@onready var outer_station: RailNodeStation3D = $"../.."

func get_station() -> RailNodeStationData:
	return outer_station.entity

func get_click_ref() -> ClickRef:
	return ClickRef.new(Enums.EntityTypes.STATION, self.get_station().num)
