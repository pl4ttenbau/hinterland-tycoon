class_name IndustryDialog extends GameDialog

@export var industry: IndustryData:
	get(): return industry
	set(value):
		industry = value
		self.set_name_and_type()
		self.set_connected_station()
		self.set_production_consumption()

#region Initialization
func _init():
	super("IndustryDialog")
	
func set_name_and_type():
	# set name label
	if self.industry.ind_name:
		%NameLabel.text = "»%s«" % self.industry.ind_name
	# set type label
	%TypeLabel.text = self.industry.ind_type.name
	
func set_connected_station():
	# get rid of default item
	%StationsTable.remove_item(0)
	# and add correct one (railway only now)
	var station_conn: StationIndustryConnection = self.industry.station_connection
	if station_conn:
		var station_name = station_conn.station.station_name
		%StationsTable.add_item(station_name, null, false)
	else:
		%StationsTable.add_item("none", null, false)
		
func set_production_consumption():
	# production
	%OutputGoodsTable.remove_item(0)
	for produced: TransformedGood in self.industry.ind_type.produces:
		var res_name: String = produced.res_key
		var res_used: float = produced.res_modifier
		var res_total: float = self.industry.storage.get_amount(produced.res_key)
		var produced_text = "%.2f x %s (total: %.2f)" % [res_used, res_name, res_total]
		%OutputGoodsTable.add_item(produced_text, null, false)
	# consumption
	%InputGoodsTable.remove_item(0)
	for required: TransformedGood in self.industry.ind_type.requires:
		var res_name: String = required.res_key
		var res_used: float = required.res_modifier
		var res_total: float = self.industry.storage.get_amount(required.res_key)
		var required_text = "%.2f x %s (total: %.2f)" % [res_used, res_name, res_total]
		%InputGoodsTable.add_item(required_text, null, false)
	pass

func _ready() -> void:
	# unlocke mouse from player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# bind signals
	%CloseButton.pressed.connect(Callable(self, "_on_close_button_click"))
	
#region Actions
func close():
	Loggie.info("Closing...")
	super.close()
#endregion

#region Callbacks
func _on_close_button_click():
	self.close()
#endregion
