class_name IndustryCollider extends ClickableCollider

@onready var outer_industry: Industry3D = self.get_parent_node_3d()

func get_industry() -> RailNodeStationData:
	return outer_industry.entity

func get_click_ref() -> ClickRef:
	return ClickRef.new(Enums.EntityTypes.STATION, self.get_industry().num)
