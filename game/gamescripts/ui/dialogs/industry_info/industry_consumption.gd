class_name IndustryConsumption extends MarginContainer

@export var industry: IndustryData:
	get(): return industry
	set(value):
		industry = value
		self._build_table()

func _build_table():
	# remove placeholder
	%GoodsTable.remove_item(0)
	# fill again from industry
	for required: TransformedGood in self.industry.ind_type.requires:
		var res_name: String = required.res_key
		var res_used: float = required.res_modifier
		var res_total: float = self.industry.storage.get_amount(required.res_key)
		var required_text = "%.2f x %s (total: %.2f)" % [res_used, res_name, res_total]
		%GoodsTable.add_item(required_text, null, false)
