## Two flows in the same waypoint-style modal: create an interchange or extend one.
extends ModalGameDialog

var tool: StationCreator
var placement: Dictionary
var nearby: Array[InterchangeData] = []
var _name: LineEdit
var _town: OptionButton
var _station: OptionButton
var _settings: OptionButton
var _status: Label

static func create(source: StationCreator, location: Dictionary) -> ModalGameDialog:
	var frame: Control = load("res://scenes/ui/dialogs/default_dialog.tscn").instantiate()
	frame.set_script(load("res://game/gamescripts/ui/dialogs/station_creator/station_creator_dialog.gd"))
	frame.tool = source
	frame.placement = location.duplicate(true)
	frame.nearby = source.nearby_interchanges(location.origin)
	return frame

func _ready() -> void:
	var adding: bool = not nearby.is_empty()
	title_text = "Add stop to station" if adding else "Create station"
	dialog_key = "AddStationStopDialog" if adding else "CreateStationDialog"
	_suspend_world_input()
	get_node("OuterPanel/OuterMargin").custom_minimum_size.y = 0
	get_node("OuterPanel/OuterMargin/OuterVLayout").custom_minimum_size.x = 460
	var panel: Control = get_node("OuterPanel")
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -210
	panel.offset_bottom = 210
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	get_node("OuterPanel/OuterMargin/OuterVLayout/Container").add_child(content)
	_add_label(content, "Road stop at your position" if placement.domain == "ROAD" else "Rail stop at your position")
	if adding:
		_build_existing(content)
	else:
		_build_new(content)
	_add_label(content, "Road side" if placement.domain == "ROAD" else "Stop type")
	_settings = OptionButton.new()
	_settings.name = "StopSettings"
	content.add_child(_settings)
	if placement.domain == "ROAD":
		for label: String in ["Left", "Right", "Both"]:
			_settings.add_item(label)
		_settings.select(placement.side)
		_add_label(content, "Sides follow the road's direction.")
	else:
		_settings.add_item("Passenger")
		_settings.add_item("Goods")
	_status = _add_label(content, "")
	_status.name = "Status"
	var confirm: Button = get_node("%OkButton")
	confirm.text = "Add stop" if adding else "Create station"
	confirm.pressed.connect(_confirm)
	confirm.disabled = not adding and _town.item_count == 0
	if confirm.disabled:
		_status.text = "No towns are available for this station."
	var row := HBoxContainer.new()
	confirm.get_parent().add_child(row)
	confirm.reparent(row)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close_all)
	row.add_child(cancel)
	if _name != null:
		_name.grab_focus()
		_name.select_all()
	else:
		_settings.grab_focus()

func _build_existing(content: VBoxContainer) -> void:
	if nearby.size() == 1:
		_add_label(content, "Station: %s" % nearby[0].interchange_name)
		_add_label(content, "Town: %s" % nearby[0].town_name)
	else:
		_add_label(content, "Nearby station (within 50 m)")
		_station = OptionButton.new()
		_station.name = "ExistingStation"
		for interchange: InterchangeData in nearby:
			_station.add_item("%s — %s" % [interchange.interchange_name, interchange.town_name])
		content.add_child(_station)
	_add_label(content, "The new stop shares this station's name and town.")

func _build_new(content: VBoxContainer) -> void:
	_add_label(content, "Station name")
	_name = LineEdit.new()
	_name.name = "StationName"
	_name.text = "Station %d" % Managers.interchanges.next_interchange_num()
	_name.text_submitted.connect(func(_text: String): _confirm())
	content.add_child(_name)
	_add_label(content, "Town")
	_town = OptionButton.new()
	_town.name = "StationTown"
	content.add_child(_town)
	var nearest_distance: float = INF
	var position: Vector2 = Vector2(placement.origin.x, placement.origin.z)
	for town: TownData in GlobalState.towns:
		_town.add_item(town.town_name, town.num)
		var distance: float = position.distance_squared_to(town.pos_xz)
		if distance < nearest_distance:
			nearest_distance = distance
			_town.select(_town.item_count - 1)

func _add_label(content: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label

func _confirm() -> void:
	if _closing:
		return
	if not is_instance_valid(tool):
		_status.text = "Station services are no longer available."
		return
	var interchange_num: int = -1
	var town_num: int = -1
	var station_name: String = ""
	if not nearby.is_empty():
		interchange_num = nearby[_station.selected if _station != null else 0].num
	else:
		station_name = _name.text
		if _town.selected >= 0:
			town_num = _town.get_selected_id()
	var station_type: String = "STATION_PASS" if _settings.selected == 0 else "STATION_GOODS"
	var side: Enums.RoadSide = _settings.selected as Enums.RoadSide if placement.domain == "ROAD" else Enums.RoadSide.RIGHT
	var result: Dictionary = tool.create_stop(placement, interchange_num, station_name, town_num, station_type, side)
	if result.has("error"):
		_status.text = result.error
		return
	diag_result = result.stop.num
	close_all()
