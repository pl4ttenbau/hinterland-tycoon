## Placement is captured before opening; naming never shifts the anchor's road position.
class_name RoadMarkerDialog extends ModalGameDialog

const PLACEMENT_TOOL = preload("res://game/gamescripts/nodes/marker/road_marker_tool.gd")

var tool: PLACEMENT_TOOL
var placement: Dictionary
var _name: LineEdit
var _side: OptionButton
var _status: Label

static func create(source: PLACEMENT_TOOL, position: Dictionary) -> RoadMarkerDialog:
	var frame: Control = load("res://scenes/ui/dialogs/default_dialog.tscn").instantiate()
	frame.set_script(RoadMarkerDialog)
	var dialog := frame as RoadMarkerDialog
	dialog.tool = source
	dialog.placement = position.duplicate()
	return dialog

func _ready() -> void:
	title_text = "Place road marker"
	dialog_key = "RoadMarkerDialog"
	$OuterPanel.custom_minimum_size = Vector2(500, 340)
	var content: VBoxContainer = %Content
	_name = LineEdit.new()
	_name.text = "Marker %d" % tool.roads.markers.next_num()
	_name.text_submitted.connect(func(_text: String): _confirm())
	content.add_child(_name)
	_side = OptionButton.new()
	for title: String in ["Left", "Right", "Both"]:
		_side.add_item(title)
	_side.select(placement.side)
	content.add_child(_side)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	_build_buttons()
	_name.grab_focus()
	_name.select_all()

func _build_buttons() -> void:
	var confirm: Button = %OkButton
	confirm.show()
	success_btn_text = "Place marker"
	confirm.pressed.connect(_confirm)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cancel: Button = %CancelButton
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _confirm() -> void:
	if _closing:
		return
	if not is_instance_valid(tool):
		_status.text = "The road is no longer available."
		return
	placement.side = _side.selected
	var marker: RoadMarkerData = tool.place(placement, _name.text)
	if marker == null:
		_status.text = "The road has changed. Close this dialog and place again."
		return
	diag_result = marker.num
	close_all()
