class_name RoadDepotCollider extends ClickableCollider

var depot_obj: RoadDepotData:
	get():
		var depot3d: RoadDepot3D = self.get_parent_node_3d()
		return depot3d.depot

func get_click_ref() -> ClickRef:
	return ClickRef.new(Enums.EntityTypes.ROAD_DEPOT, self.depot_obj.num)
