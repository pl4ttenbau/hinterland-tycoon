@icon("res://assets/icons/icon_gears_white.png")
class_name IndustryProduction extends Node

const PRODUCTION_TIMER_SECONDS = 5.0

@export var industry3d: Industry3D

func _ready() -> void:
	if !self.industry3d:
		var parent: Node = self.get_parent()
		if parent is Industry3D:
			self.industry3d = parent
	self.add_production_timer()

func add_production_timer():
	var production_timer: Timer = Timer.new()
	production_timer.wait_time = PRODUCTION_TIMER_SECONDS
	production_timer.one_shot = false
	production_timer.timeout.connect(Callable(self, "_on_production_timeout"))
	self.add_child(production_timer)
	production_timer.start(PRODUCTION_TIMER_SECONDS)

#region Inventory
func produce_good(good_type_key: String):
	var amount: int = self.get_produced_amount(good_type_key)
	var spawned_good: SpawnedGood = SpawnedGood.new(good_type_key, amount)
	self.get_inventory().add_spawned_good(spawned_good)

func has_required_goods() -> bool:
	if !self.get_ind_obj():
		Loggie.warn("Cannot get industry obj of %s" % self.name)
		return false
	elif !self.get_ind_obj().ind_type:
		Loggie.warn("Cannot get industry type of %s" % self.name)
		return false
	for required_res: TransformedGood in self.get_ind_obj().ind_type.requires:
		@warning_ignore("narrowing_conversion")
		var spawned_good := SpawnedGood.new(required_res.res_key, required_res.res_modifier)
		if ! self.get_inventory().has_enough(spawned_good): return false
	return true

func get_produced_amount(good_type_key: String) -> int:
	var ind_type: IndustryType = self.get_ind_obj().ind_type
	for produced_good: TransformedGood in ind_type.produces:
		if produced_good.res_key == good_type_key:
			return produced_good.res_modifier as int
	return 0
#endregion

#region Node Getters
func get_ind_obj() -> IndustryData:
	return self.industry3d.industry

func get_inventory() -> GoodsInventory:
	return self.industry3d.get_inventory()
#endregion

#region Callbacks
func _on_production_timeout():
	if ! self.industry3d:
		Loggie.warn("Error in %s: industry type not loaded" % self.name)
		return
	if self.has_required_goods():
		for produced_good: TransformedGood in self.get_ind_obj().ind_type.produces:
			Loggie.info("adding %s to storage %s" % [produced_good.res_key, self.get_inventory().storage])
			self.produce_good(produced_good.res_key)
#endregion
