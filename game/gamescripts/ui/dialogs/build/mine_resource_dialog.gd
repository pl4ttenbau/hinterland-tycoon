## Second step of building a mine: after the player placed the mine in the 3D
## preview, choose which resource it extracts. Lists every resource the survey
## found at the site, with its richness. The dialog only asks: MinePlacement
## sets on_submit, which checks the site and the company's cash, builds the mine
## and closes the dialog, or returns why it cannot.
class_name MineResourceDialog extends ConfirmDialog

var construction_cost: int
var readings: Dictionary[String, float]
var _resources: Array[String] = []

@onready var _choices: OptionButton = %ResourceChoices
## The frame's primary button: Build mine.
@onready var _build: Button = %OkButton


func _ready() -> void:
	# 1. Content: one choice per resource found at this site.
	_fill_resources()
	# 2. Initial state: building needs at least one resource.
	_build.text = "Build mine · %s" % CompanyData.format_cash(construction_cost)
	_build.disabled = _resources.is_empty()
	if _resources.is_empty():
		show_status("There are no resources to mine at this site.", StatusTone.ERROR)
	else:
		clear_status()
	_choices.grab_focus()


func _fill_resources() -> void:
	for resource: String in readings:
		if readings[resource] > 0.0:
			_resources.append(resource)
			_choices.add_item("%s · %s" % [
				ProspectDialog.resource_name(resource), ProspectDialog.richness_text(readings[resource]),
			])


## Hands the chosen resource to MinePlacement's handler (see on_submit).
func submit() -> String:
	if _choices.selected < 0 or _choices.selected >= _resources.size():
		return "Choose an available resource."
	if not on_submit.is_valid():
		return "Mine construction is unavailable."
	return on_submit.call(_resources[_choices.selected])
