@icon("res://assets/icons/icon_industry.png")
class_name OuterIndustry extends HideableObject

static var last_ind_num: int = 0
static var PRODUCTION_TIMER_SECONDS = 5.0

@export_storage var bld_num: int

@export var industry: IndustryData:
	get(): return self.entity as IndustryData
	set(value): 
		self.entity = value
		self.position = value.pos
		self._set_name(value)
		
#region Initialization
func _enter_tree() -> void:
	var production_timer: Timer = Timer.new()
	production_timer.wait_time = PRODUCTION_TIMER_SECONDS
	production_timer.one_shot = false
	production_timer.timeout.connect(Callable(self, "_on_production_timeout"))
	self.add_child(production_timer)
	production_timer.start(PRODUCTION_TIMER_SECONDS)
#endregion

#region Production
func produce_good(good_type_key: String):
	var amount: int = self.industry.get_produced_amount(good_type_key)
	self.industry.storage.change_amount(good_type_key, amount)
#endregion
	
#region Callbacks
func _on_production_timeout():
	if ! self.industry || ! self.industry.ind_type:
		Loggie.warn("Error in %s: industry type not loaded" % self.name)
		return
	if self.industry.has_required_goods():
		for produced_good: TransformedGood in self.industry.ind_type.produces:
			self.produce_good(produced_good.res_key)
#endregion

#region Helper-Methods
func _set_name(ind_obj: IndustryData):
	var underscored: String = ind_obj.ind_name.replace(" ", "_")
	self.name = underscored
#endregion
