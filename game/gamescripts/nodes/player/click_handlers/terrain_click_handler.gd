@icon("res://assets/icons/icon_gears_white.png")
class_name TerrainClickHandler extends AbstractClickHandler

func handle_click(entity_collider: Node3D, ray_result: Dictionary) -> bool:
	if ! entity_collider is Terrain3D:
		return false
	var click_pos: Vector3 = ray_result.get("position")
	Loggie.info("Click on terrain at %v" % click_pos)
	SignalBus.terrain_click.emit(click_pos)
	# get_viewport().set_input_as_handled()
	return true
