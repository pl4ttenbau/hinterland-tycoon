## Names a rail signal and chooses which direction of travel it protects. The location is captured before opening.
class_name RailSignalDialog extends ModalGameDialog

const PLACEMENT_TOOL = preload("res://game/gamescripts/nodes/marker/rail_signal_tool.gd")

## Option order in the facing selector.
enum Choice { VIEW_DIRECTION, OPPOSITE, BOTH }

var tool: PLACEMENT_TOOL
var placement: Dictionary
var _name: LineEdit
var _facing: OptionButton
var _status: Label

static func create(source: PLACEMENT_TOOL, position: Dictionary) -> RailSignalDialog:
	var frame: Control = load("res://scenes/ui/dialogs/default_dialog.tscn").instantiate()
	frame.set_script(RailSignalDialog)
	var dialog := frame as RailSignalDialog
	dialog.tool = source
	dialog.placement = position.duplicate()
	return dialog

func _ready() -> void:
	title_text = "Place rail signal"
	dialog_key = "RailSignalDialog"
	$OuterPanel.custom_minimum_size = Vector2(500, 340)
	var content: VBoxContainer = %Content
	_name = LineEdit.new()
	_name.text = "Signal %d" % tool.rails.signals.next_num()
	_name.text_submitted.connect(func(_text: String): _confirm())
	content.add_child(_name)
	_facing = OptionButton.new()
	for title: String in ["For trains in my view direction", "For trains in the opposite direction", "For both directions"]:
		_facing.add_item(title)
	_facing.select(Choice.VIEW_DIRECTION)
	content.add_child(_facing)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	_build_buttons()
	_name.grab_focus()
	_name.select_all()

func _build_buttons() -> void:
	var confirm: Button = %OkButton
	confirm.show()
	success_btn_text = "Place signal"
	confirm.pressed.connect(_confirm)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cancel: Button = %CancelButton
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

## Translate the choice relative to the player's view into a facing along the track's node order.
func selected_facing() -> RailSignalData.Facing:
	var view_facing: RailSignalData.Facing = placement.facing
	match _facing.selected:
		Choice.BOTH:
			return RailSignalData.Facing.BOTH
		Choice.OPPOSITE:
			return RailSignalData.Facing.NODES_DECREASE if view_facing == RailSignalData.Facing.NODES_INCREASE else RailSignalData.Facing.NODES_INCREASE
		_:
			return view_facing

func _confirm() -> void:
	if _closing:
		return
	if not is_instance_valid(tool):
		_status.text = "The track is no longer available."
		return
	var rail_signal: RailSignalData = tool.place(placement, _name.text, selected_facing())
	if rail_signal == null:
		_status.text = "The track has changed. Close this dialog and place again."
		return
	diag_result = rail_signal.num
	close_all()
