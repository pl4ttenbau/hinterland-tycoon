class_name IndustryDialog extends GameDialog

@export var industry: IndustryData:
	get(): return industry
	set(value):
		industry = value
		# initialize children
		%NameAndTypeBox.industry = value
		# self.set_connected_station()
		self.set_production_consumption()

#region Initialization
func _init():
	super()
	self.dialog_key = "IndustryDialog"
	
func set_name_and_type():
	# set name label
	if self.industry.ind_name:
		%NameLabel.text = "»%s«" % self.industry.ind_name
	# set type label
	%TypeLabel.text = self.industry.ind_type.name
	
func set_connected_station():
	%IndustryStationList.industry = self.industry
	
func set_production_consumption():
	%IndustryProduction.industry = self.industry
	%IndustryConsumption.industry = self.industry

func _ready() -> void:
	# unlocke mouse from player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# bind signals
	%CloseButton.pressed.connect(Callable(self, "_on_close_button_click"))

#region Callbacks
func _on_close_button_click():
	super.close_all()
#endregion
