## Placement is captured before opening; naming never shifts the anchor's road position.
class_name RoadMarkerDialog extends PlacementNameDialog

const SCENE_PATH := "res://scenes/ui/dialogs/road_marker/road_marker_dialog.tscn"
const PLACEMENT_TOOL = preload("res://game/gamescripts/nodes/marker/road_marker_tool.gd")

var tool: PLACEMENT_TOOL
var placement: Dictionary

static func create(source: PLACEMENT_TOOL, position: Dictionary) -> RoadMarkerDialog:
	var dialog := (load(SCENE_PATH) as PackedScene).instantiate() as RoadMarkerDialog
	dialog.tool = source
	dialog.placement = position.duplicate()
	return dialog

func _ready() -> void:
	_choice.select(placement.side)
	super()

func default_name() -> String:
	return "Marker %d" % tool.roads.markers.next_num()

## Places the marker and closes with its number, or explains why it cannot.
func submit() -> String:
	if not is_instance_valid(tool):
		return "The road is no longer available."
	placement.side = _choice.selected
	var marker: RoadMarkerData = tool.place(placement, _name.text)
	if marker == null:
		return "The road has changed. Close this dialog and place again."
	close_with(marker.num)
	return ""
