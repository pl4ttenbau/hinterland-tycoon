class_name ProspectDialog extends MenuShellDialog

signal prospect_requested()

const TRACE_RICHNESS: float = 0.10
const RESOURCE_NAMES: Dictionary[String, String] = {
	"stone": "Stone",
	"gravel": "Gravel",
	"coal": "Coal",
	"ore": "Iron ore",
}

var readings: Dictionary[String, float]
var message: String
var can_prospect: bool = false

@onready var _status: Label = %Status
@onready var _grid: GridContainer = %Readings


func _ready() -> void:
	dialog_key = "ProspectDialog"
	title_text = "Prospecting"
	super._ready()
	if can_prospect:
		_add_prospect_button()
	show_readings(readings)


func show_readings(result: Dictionary[String, float]) -> void:
	readings = result
	if message.is_empty():
		_status.text = "Unsurveyed" if readings.is_empty() else "Richness at the surveyed spot"
	else:
		_status.text = message
	_grid.visible = not readings.is_empty()
	for child: Node in _grid.get_children():
		child.free()
	for resource: String in readings:
		var resource_label := Label.new()
		resource_label.text = resource_name(resource)
		resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(resource_label)

		var reading_label := Label.new()
		reading_label.text = richness_text(readings[resource])
		reading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_grid.add_child(reading_label)


static func resource_name(resource: String) -> String:
	return RESOURCE_NAMES.get(resource, resource.capitalize())


static func richness_text(richness: float) -> String:
	return "Trace" if richness > 0.0 and richness < TRACE_RICHNESS else "%d%%" % roundi(richness * 100.0)


func _add_prospect_button() -> void:
	# Reuse the shell's Close button and its existing modal connection in the two-button footer.
	var close_button: Button = %OkButton
	var actions := HBoxContainer.new()
	close_button.get_parent().add_child(actions)
	close_button.reparent(actions)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var prospect_button := Button.new()
	prospect_button.name = "ProspectButton"
	prospect_button.text = "Prospect"
	prospect_button.theme_type_variation = &"PrimaryButton"
	prospect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prospect_button.pressed.connect(prospect_requested.emit)
	actions.add_child(prospect_button)
	actions.move_child(prospect_button, 0)
	prospect_button.grab_focus()
