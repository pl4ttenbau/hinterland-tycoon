## Scene-authored form shared by new interchanges and additions to existing ones.
class_name StationCreatorDialog extends ModalGameDialog

var tool: StationCreator
var placement: Dictionary
var nearby: Array[InterchangeData] = []
var _preview: Node3D
var _preview_type_index: int = 0

@onready var _name: LineEdit = %StationName
@onready var _town: OptionButton = %StationTown
@onready var _station: OptionButton = %ExistingStation
@onready var _road_side: OptionButton = %RoadSide
@onready var _platform_type: OptionButton = %PlatformType
@onready var _platform_side: OptionButton = %PlatformSide
@onready var _hide_platform: CheckBox = %HidePlatform
@onready var _status: Label = %Status

static func create(source: StationCreator, location: Dictionary) -> StationCreatorDialog:
	var scene: PackedScene = load("res://scenes/ui/dialogs/station_creator/station_creator_dialog.tscn")
	var frame := scene.instantiate() as StationCreatorDialog
	frame.tool = source
	frame.placement = location.duplicate(true)
	frame.nearby = source.nearby_interchanges(location.origin)
	frame._preview = source.make_rail_preview(location) if location.domain == "RAIL" else source.make_road_preview(location)
	if frame._preview == null:
		frame.free()
		return null
	# The modal owns the preview. Confirming, cancelling, or unloading frees it
	# along with the form.
	frame.add_child(frame._preview)
	return frame

func _ready() -> void:
	var adding: bool = not nearby.is_empty()
	var rail_placement: bool = placement.domain == "RAIL"
	title_text = "Build platform" if rail_placement else ("Add stop to station" if adding else "Create station")
	dialog_key = "AddStationStopDialog" if adding else "CreateStationDialog"
	%NewStation.visible = not adding
	%ExistingStationOptions.visible = adding
	%RailOptions.visible = rail_placement
	%RoadOptions.visible = not rail_placement
	if adding:
		_build_existing()
	else:
		_build_new()
	if rail_placement:
		_build_platform_options()
	else:
		_build_road_options()

	var confirm: Button = %OkButton
	var action: String = "Yes" if rail_placement else ("Add stop" if adding else "Create station")
	confirm.text = "%s · %s" % [action, CompanyData.format_cash(CompanyData.STOP_COST)]
	confirm.pressed.connect(_confirm)
	confirm.disabled = not adding and _town.item_count == 0
	if confirm.disabled:
		_status.text = "No towns are available for this station."
	%CancelButton.text = "No" if rail_placement else "Cancel"
	%CancelButton.pressed.connect(close_all)
	if not adding:
		_name.grab_focus()
		_name.select_all()
	elif rail_placement:
		_platform_type.grab_focus()
	else:
		_road_side.grab_focus()

func _build_road_options() -> void:
	var increasing := Enums.RoadStopDirection.ROAD_NODES_INCREASE
	var decreasing := Enums.RoadStopDirection.ROAD_NODES_DECREASE
	var right: int = placement.right_direction
	var left: int = decreasing if right == increasing else increasing
	# The visible labels are player-relative. The item IDs still go straight to
	# the builder and the road router as stable directions along the road.
	_road_side.add_item("Left", left)
	_road_side.add_item("Right", right)
	_road_side.add_item("Both sides", Enums.RoadStopDirection.BOTH_DIRECTIONS)
	_road_side.select(_road_side.get_item_index(placement.direction))
	_road_side.item_selected.connect(_update_road_preview.unbind(1))
	_update_road_preview()

func _update_road_preview() -> void:
	var direction: int = _road_side.get_selected_id()
	_preview.get_node("ForwardShelter").visible = direction != Enums.RoadStopDirection.ROAD_NODES_DECREASE
	_preview.get_node("ReverseShelter").visible = direction != Enums.RoadStopDirection.ROAD_NODES_INCREASE

func _build_platform_options() -> void:
	_platform_type.add_item("Passenger")
	_platform_type.set_item_metadata(0, "STATION_PASS")
	_platform_type.add_item("Cargo")
	_platform_type.set_item_metadata(1, "STATION_GOODS")
	_platform_type.item_selected.connect(_change_platform_model)
	_platform_side.add_item("Right", RailStationData.PlatformSide.RIGHT)
	_platform_side.add_item("Left", RailStationData.PlatformSide.LEFT)
	_platform_side.item_selected.connect(_update_platform_preview.unbind(1))
	_hide_platform.toggled.connect(_update_platform_preview.unbind(1))


func _change_platform_model(index: int) -> void:
	if not is_instance_valid(tool):
		_platform_type.select(_preview_type_index)
		return
	var model: BuildingMesh3D = tool.make_rail_preview_model(_platform_type.get_item_metadata(index))
	if model == null:
		_platform_type.select(_preview_type_index)
		_status.text = "The selected platform preview is unavailable."
		return
	var previous: Node3D = _preview.get_node("PlatformModel")
	_preview.remove_child(previous)
	previous.queue_free()
	_preview.add_child(model)
	_preview_type_index = index
	_status.text = ""
	_update_platform_preview()


func _update_platform_preview() -> void:
	var side: int = _platform_side.get_selected_id()
	var previous_side: int = placement.get("platform_side", RailStationData.PlatformSide.RIGHT)
	if side != previous_side:
		_preview.rotate_y(PI)
	placement.platform_side = side
	placement.hide_platform = _hide_platform.button_pressed
	_preview.get_node("PlatformModel").visible = not _hide_platform.button_pressed
	_preview.get_node("StopMarker").visible = _hide_platform.button_pressed


func _build_existing() -> void:
	_station.visible = nearby.size() > 1
	if nearby.size() == 1:
		%ExistingStationLabel.text = "%s · %s" % [nearby[0].interchange_name, nearby[0].town_name]
		return
	for interchange: InterchangeData in nearby:
		_station.add_item("%s — %s" % [interchange.interchange_name, interchange.town_name])

func _build_new() -> void:
	_name.text = "Station %d" % Managers.interchanges.next_interchange_num()
	_name.text_submitted.connect(func(_text: String): _confirm())
	var nearest_distance: float = INF
	var position: Vector2 = Vector2(placement.origin.x, placement.origin.z)
	for town: TownData in GlobalState.towns:
		_town.add_item(town.town_name, town.num)
		var distance: float = position.distance_squared_to(town.pos_xz)
		if distance < nearest_distance:
			nearest_distance = distance
			_town.select(_town.item_count - 1)

func _confirm() -> void:
	if _closing or %OkButton.disabled:
		return
	if not is_instance_valid(tool):
		_status.text = "Station services are no longer available."
		return
	var interchange_num: int = -1
	var town_num: int = -1
	var station_name: String = ""
	if not nearby.is_empty():
		interchange_num = nearby[_station.selected if _station.visible else 0].num
	else:
		station_name = _name.text
		if _town.selected >= 0:
			town_num = _town.get_selected_id()
	var station_type: String = ""
	var direction := Enums.RoadStopDirection.ROAD_NODES_INCREASE
	if placement.domain == "ROAD":
		direction = _road_side.get_selected_id() as Enums.RoadStopDirection
	else:
		station_type = _platform_type.get_selected_metadata()
	var result: Dictionary = tool.create_stop(placement, interchange_num, station_name, town_num, station_type, direction)
	if result.has("error"):
		_status.text = result.error
		return
	diag_result = result.stop.num
	close_all()
