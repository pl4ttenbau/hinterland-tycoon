@warning_ignore("missing_tool")
class_name InventoryTransferDialog extends GameDialog

#region Initialization
func _init():
	super()
	self.dialog_key = "InventoryTransferDiag"

func _ready() -> void:
	# unlocke mouse from player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _enter_tree() -> void:
	# bind signals
	%CloseButton.pressed.connect(Callable(self, "_on_close_button_click"))

func build_sides():
	pass
#endregion

#region Callbacks
func _on_close_button_click():
	super.close_all()
#endregion
