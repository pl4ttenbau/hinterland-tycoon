## Which nearby interchange a new stop joins. A single candidate is shown as text.
class_name ExistingStationPicker extends VBoxContainer

var _nearby: Array[InterchangeData] = []

@onready var _label: Label = %ExistingStationLabel
@onready var _station: OptionButton = %ExistingStation

func setup(nearby: Array[InterchangeData]) -> void:
	_nearby = nearby
	_station.visible = nearby.size() > 1
	if nearby.size() == 1:
		_label.text = "%s · %s" % [nearby[0].interchange_name, nearby[0].town_name]
		return
	for interchange: InterchangeData in nearby:
		_station.add_item("%s — %s" % [interchange.interchange_name, interchange.town_name])

func selected_interchange() -> InterchangeData:
	return _nearby[_station.selected if _station.visible else 0]
