@icon("res://assets/icons/icon_gears_white.png")
class_name BaseEntityClickHandler extends Node

static var INDUSTRY_DIAG_PATH = "res://scenes/ui/dialogs/industry_dialog.tscn"

func handle_click(entity_collider: Node3D) -> bool:
	if !entity_collider || ! entity_collider is ClickableCollider: 
		return false
	if entity_collider is RailForkCollider:
		var fork: NewRailForkData = entity_collider.get_fork()
		if fork:
			fork.switch()
		return true
	if entity_collider is IndustryCollider:
		self.on_industry_click(entity_collider)
		return true
	if entity_collider is ClickableCollider:
		var c_ref: ClickRef = entity_collider.get_click_ref()
		SignalBus.collider_click.emit(c_ref)
		if c_ref.get_type_str():
			Loggie.info("Click %s %d" % [c_ref.get_type_str(), c_ref.entity_num])
		return true
	return false
	
func on_industry_click(c_ref: IndustryCollider):
	var ind_num: int = c_ref.get_click_ref().entity_num
	var clicked_ind: IndustryData = IndustryData.get_by_num(ind_num)
	# open diag
	var diag_scene: PackedScene = load(INDUSTRY_DIAG_PATH)
	# open industry dialog
	var instance: IndustryDialog = diag_scene.instantiate()
	instance.industry = clicked_ind
	$/root.add_child(instance)
