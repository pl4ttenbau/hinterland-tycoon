## Form shared by new interchanges and additions to existing ones. Each section
## is its own scene; this dialog shows the relevant ones, keeps the 3D preview
## in sync with them, and hands the result to StationCreator.
##
## Opened by the Build picker's Create stop tool where the player stands: on a
## road it adds a bus stop, on a track a rail platform. With an interchange
## nearby, the stop joins it (no name or town to choose); otherwise the form
## creates a new interchange.
class_name StationCreatorDialog extends ConfirmDialog

const SCENE_PATH := "res://scenes/ui/dialogs/station_creator/station_creator_dialog.tscn"

var tool: StationCreator
## Where and how the stop is built, as captured by StationCreator.placement_at():
## domain ("ROAD" or "RAIL"), origin, and per domain the stop direction (road)
## or platform side and visibility (rail). The form writes the player's choices
## back into it, and create_stop() receives it on confirm.
var placement: Dictionary
## Interchanges close enough to join. Empty means "create a new one".
var nearby: Array[InterchangeData] = []
## 3D preview at the placement, owned by this dialog and freed with it.
var _preview: Node3D
## Platform type currently shown by the preview; restored when a newly chosen
## type has no preview model.
var _preview_type: String = RailPlatformOptions.STATION_TYPES[0]

@onready var _new_station: NewStationFields = %NewStation
@onready var _existing: ExistingStationPicker = %ExistingStationOptions
@onready var _road_options: RoadStopOptions = %RoadOptions
@onready var _rail_options: RailPlatformOptions = %RailOptions
@onready var _confirm_button: Button = %OkButton

static func create(source: StationCreator, location: Dictionary) -> StationCreatorDialog:
	var frame := (load(SCENE_PATH) as PackedScene).instantiate() as StationCreatorDialog
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
	# 1. Identity: the title and key depend on what is being built.
	title_text = "Build platform" if rail_placement else ("Add stop to station" if adding else "Create station")
	dialog_key = "AddStationStopDialog" if adding else "CreateStationDialog"
	# 2. Wiring.
	_connect_signals()
	# 3. Sections: show only the ones that apply, and fill them.
	_new_station.visible = not adding
	_existing.visible = adding
	_rail_options.visible = rail_placement
	_road_options.visible = not rail_placement
	if adding:
		_existing.setup(nearby)
	else:
		_new_station.setup("Station %d" % Managers.interchanges.next_interchange_num(), placement.origin)
	if not rail_placement:
		_road_options.setup(placement.right_direction, placement.direction)
		_update_road_preview(_road_options.direction())
	# 4. Buttons: the action and its cost; a new station needs a town.
	var action: String = "Yes" if rail_placement else ("Add stop" if adding else "Create station")
	_confirm_button.text = "%s · %s" % [action, CompanyData.format_cash(CompanyData.STOP_COST)]
	_confirm_button.disabled = not adding and not _new_station.has_towns()
	if _confirm_button.disabled:
		show_status("No towns are available for this station.", StatusTone.ERROR)
	%CancelButton.text = "No" if rail_placement else "Cancel"
	# 5. Focus: the first field the player is likely to change.
	if not adding:
		_new_station.focus()
	elif rail_placement:
		_rail_options.focus()
	else:
		_road_options.focus()

## OK is wired by ConfirmDialog, %CancelButton by GameDialog.
func _connect_signals() -> void:
	_new_station.submitted.connect(confirm)
	_road_options.direction_changed.connect(_update_road_preview)
	_rail_options.platform_type_changed.connect(_change_platform_model)
	_rail_options.layout_changed.connect(_update_platform_preview)

#region Preview
## Shows a shelter on each side the stop will serve.
func _update_road_preview(direction: Enums.RoadStopDirection) -> void:
	_preview.get_node("ForwardShelter").visible = direction != Enums.RoadStopDirection.ROAD_NODES_DECREASE
	_preview.get_node("ReverseShelter").visible = direction != Enums.RoadStopDirection.ROAD_NODES_INCREASE

## Swaps the preview's platform model for the chosen type (passenger or cargo).
func _change_platform_model(station_type: String) -> void:
	if not is_instance_valid(tool):
		_rail_options.select_type(_preview_type)
		return
	var model: BuildingMesh3D = tool.make_rail_preview_model(station_type)
	if model == null:
		_rail_options.select_type(_preview_type)
		show_status("The selected platform preview is unavailable.", StatusTone.ERROR)
		return
	var previous: Node3D = _preview.get_node("PlatformModel")
	_preview.remove_child(previous)
	previous.queue_free()
	_preview.add_child(model)
	_preview_type = station_type
	clear_status()
	_update_platform_preview(_rail_options.side(), _rail_options.is_platform_hidden())

## Mirrors the preview to the chosen side of the track and swaps the platform for
## a plain stop marker when it is hidden. The preview is built for the side
## stored in placement, so switching sides is a half turn around its origin.
func _update_platform_preview(side: RailStationData.PlatformSide, hidden: bool) -> void:
	var previous_side: int = placement.get("platform_side", RailStationData.PlatformSide.RIGHT)
	if side != previous_side:
		_preview.rotate_y(PI)
	placement.platform_side = side
	placement.hide_platform = hidden
	_preview.get_node("PlatformModel").visible = not hidden
	_preview.get_node("StopMarker").visible = hidden
#endregion

## Builds the stop through StationCreator, which also charges the company. On
## success the dialog closes with the new stop's number; otherwise it stays open
## with the reason.
func submit() -> String:
	if not is_instance_valid(tool):
		return "Station services are no longer available."
	var interchange_num: int = -1
	var town_num: int = -1
	var station_name: String = ""
	if not nearby.is_empty():
		interchange_num = _existing.selected_interchange().num
	else:
		station_name = _new_station.station_name()
		town_num = _new_station.town_num()
	var station_type: String = ""
	var direction := Enums.RoadStopDirection.ROAD_NODES_INCREASE
	if placement.domain == "ROAD":
		direction = _road_options.direction()
	else:
		station_type = _rail_options.station_type()
	var result: Dictionary = tool.create_stop(placement, interchange_num, station_name, town_num, station_type, direction)
	if result.has("error"):
		return result.error
	close_with(result.stop.num)
	return ""
