class_name DepotCollider extends ClickableCollider

var depot_obj: RailDepotData:
	get():
		var depot3d: RailDepot3D = self.get_parent_node_3d()
		return depot3d.depot

func get_click_ref() -> ClickRef:
	return ClickRef.new(Enums.EntityTypes.DEPOT, self.depot_obj.num)
