## Names a rail signal and chooses which direction of travel it protects. The location is captured before opening.
class_name RailSignalDialog extends PlacementNameDialog

const SCENE_PATH := "res://scenes/ui/dialogs/rail_signal/rail_signal_dialog.tscn"
const PLACEMENT_TOOL = preload("res://game/gamescripts/nodes/marker/rail_signal_tool.gd")

## Option order in the facing selector.
enum Choice { VIEW_DIRECTION, OPPOSITE, BOTH }

var tool: PLACEMENT_TOOL
var placement: Dictionary

static func create(source: PLACEMENT_TOOL, position: Dictionary) -> RailSignalDialog:
	var dialog := (load(SCENE_PATH) as PackedScene).instantiate() as RailSignalDialog
	dialog.tool = source
	dialog.placement = position.duplicate()
	return dialog

func _ready() -> void:
	_choice.select(Choice.VIEW_DIRECTION)
	super()

func default_name() -> String:
	return "Signal %d" % tool.rails.signals.next_num()

## Translate the choice relative to the player's view into a facing along the track's node order.
func selected_facing() -> RailSignalData.Facing:
	var view_facing: RailSignalData.Facing = placement.facing
	match _choice.selected:
		Choice.BOTH:
			return RailSignalData.Facing.BOTH
		Choice.OPPOSITE:
			return RailSignalData.Facing.NODES_DECREASE if view_facing == RailSignalData.Facing.NODES_INCREASE else RailSignalData.Facing.NODES_INCREASE
		_:
			return view_facing

## Places the signal and closes with its number, or explains why it cannot.
func submit() -> String:
	if not is_instance_valid(tool):
		return "The track is no longer available."
	var rail_signal: RailSignalData = tool.place(placement, _name.text, selected_facing())
	if rail_signal == null:
		return "The track has changed. Close this dialog and place again."
	close_with(rail_signal.num)
	return ""
