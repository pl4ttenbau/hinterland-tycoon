class_name RailForkCollider extends ClickableCollider

@onready var outer_rail_fork: RailFork3D = self.get_parent_node_3d()

func get_fork() -> NewRailForkData:
	return outer_rail_fork.entity

func get_click_ref() -> ClickRef:
	return ClickRef.new(Enums.EntityTypes.FORK, -1)
