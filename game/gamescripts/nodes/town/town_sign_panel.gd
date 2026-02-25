@tool
class_name TownSignPanel extends PanelContainer

@export var town3d: Town3D:
	get(): return town3d
	set(value):
		town3d = value
		

@export var town_name: String:
	get(): return town_name
	set(value):
		town_name = value
		%TownNameLabel.text = value
		
@export var pops_amount: int:
	get(): return pops_amount
	set(value):
		pops_amount = value
		%PopsAmountLabel.text = str(value)

func _set_town(_town3d: Town3D):
	self.town3d = _town3d
	if ! _town3d.town:
		Loggie.error("Cannot find TownData in Town3D \"%s\"" % self.get_path())
		return
	if town3d.town.town_name:
		self.town_name = town3d.town.town_name
	if town3d.town.totalPops:
		self.pops_amount = town3d.town.totalPops
