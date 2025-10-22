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
	pass
	
func set_production_consumption():
	pass

func _ready() -> void:
	# unlock mouse
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	# bind signals
	%CloseButton.pressed.connect(Callable(self, "_on_close_button_click"))
	# initialize depot list
	
#region Actions
func close():
	Loggie.info("Closing...")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	super.close()

#endregion

#region Callbacks
func _on_close_button_click():
	self.close()
#endregion
