class_name IndustryProduction extends MarginContainer

@export var industry: IndustryData:
	get(): return industry
	set(value):
		industry = value
		self._build_table()
	
func _build_table():
	# remove placeholder
	%GoodsTable.remove_item(0)
	# fill again with industry data
	for produced: TransformedGood in self.industry.ind_type.produces:
		var res_name: String = produced.res_key
		var res_used: float = produced.res_modifier
		var res_total: float = self.industry.storage.get_amount(produced.res_key)
		var produced_text = "%.2f x %s (total: %.2f)" % [res_used, res_name, res_total]
		%GoodsTable.add_item(produced_text, null, false)
