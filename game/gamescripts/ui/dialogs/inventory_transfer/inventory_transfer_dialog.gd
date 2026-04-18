@warning_ignore("missing_tool")
class_name InventoryTransferDialog extends GameDialog

signal transfer_goods(transfer: GoodsTransfer)

#region Initialization
func _init():
	super()
	self.dialog_key = "InventoryTransferDiag"

func _ready() -> void:
	# unlocke mouse from player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# bind signals
	self.transfer_goods.connect(Callable(self, "_on_transfer_goods"))
	%CloseButton.pressed.connect(Callable(self, "_on_close_button_click"))
	%InventorySideL.transfer_out.connect(Callable(self, "_on_side_transfer_out"))
	%InventorySideR.transfer_out.connect(Callable(self, "_on_side_transfer_out"))

func build_sides():
	pass
#endregion

func get_target_side(source_entity: InventoryEntity3D) -> InventoryTransferSideUi:
	if source_entity == %InventorySideL.selected_entity:
		return %InventorySideR
	elif source_entity == %InventorySideR.selected_entity:
		return %InventorySideL
	return null

#region Callbacks
func _on_close_button_click():
	super.close_all()

func _on_transfer_goods(transfer: GoodsTransfer):
	var target_side: InventoryTransferSideUi = self.get_target_side(transfer.from)
	var target_entity: InventoryEntity3D = target_side.selected_entity
	if ! target_entity:
		Loggie.warn("Cannot transfer inventory: other side is empty")
		return
	transfer.to = target_entity
	target_side.transfer_in.emit(transfer)

func _on_side_transfer_out(transfer: GoodsTransfer):
	self.transfer_goods.emit(transfer)
#endregion
