## Survey readings at one spot: how rich each mineable resource is there.
## Two uses, set up by Prospecting:
## - Prospect action: opens unsurveyed, with Prospect as the OK button (can_prospect);
##   pressing it emits prospect_requested, and the survey places a sign.
## - Clicking a survey sign: shows that sign's stored readings, no button.
## message replaces the heading line when prospecting is not possible here.
class_name ProspectDialog extends ModalGameDialog

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

## Heading above the readings: unsurveyed, surveyed, or why prospecting is not
## possible here. Content, not the frame's status line.
@onready var _survey_state: Label = %SurveyState
@onready var _grid: GridContainer = %Readings


func _ready() -> void:
	# 1. Wiring.
	%OkButton.pressed.connect(_on_prospect_button_pressed)
	# 2. Initial state: Prospect (the frame's OK) is only offered where a survey
	#    can start; otherwise Close is the only button.
	%OkButton.visible = can_prospect
	if can_prospect:
		%OkButton.grab_focus()
	else:
		%CancelButton.grab_focus()
	# 3. Content.
	show_readings(readings)


func show_readings(result: Dictionary[String, float]) -> void:
	readings = result
	if message.is_empty():
		_survey_state.text = "Unsurveyed" if readings.is_empty() else "Richness at the surveyed spot"
	else:
		_survey_state.text = message
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




func _on_prospect_button_pressed() -> void:
	prospect_requested.emit()
