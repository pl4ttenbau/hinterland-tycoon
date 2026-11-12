class_name MineResourceDialog extends MenuShellDialog

signal build_requested(resource: String)

var readings: Dictionary[String, float]
var _resources: Array[String] = []

@onready var _choices: OptionButton = %ResourceChoices
@onready var _build: Button = %BuildButton


func _ready() -> void:
	dialog_key = "MineResourceDialog"
	title_text = "Choose a mine resource"
	super._ready()
	%OkButton.text = "Cancel"
	for resource: String in readings:
		if readings[resource] > 0.0:
			_resources.append(resource)
			_choices.add_item("%s · %s" % [
				ProspectDialog.resource_name(resource), ProspectDialog.richness_text(readings[resource]),
			])
	_build.disabled = _resources.is_empty()
	%Status.visible = _resources.is_empty()
	_choices.grab_focus()


func show_error(message: String) -> void:
	%Status.text = message
	%Status.show()


func _on_build_pressed() -> void:
	if not _closing and _choices.selected >= 0 and _choices.selected < _resources.size():
		build_requested.emit(_resources[_choices.selected])
