class_name LoadUnloadAction extends BaseAction

const TRANSFER_INV_DIAG_SCENE = "res://scenes/ui/dialogs/transfer_inventory/transfer_inventory_dialog.tscn"

func on_trigger():
	if UiState.current_diag != null:
		return
	super.on_trigger()
	self.show_transfer_inventory_diag()

func show_transfer_inventory_diag():
	var diag_scene: PackedScene = load(TRANSFER_INV_DIAG_SCENE)
	var diag_instance: InventoryTransferDialog = diag_scene.instantiate()
	$/root.add_child(diag_instance)
