class_name LoadUnloadAction extends BaseAction

const TRANSFER_INV_DIAG_SCENE = "res://scenes/ui/dialogs/transfer_inventory/transfer_inventory_dialog.tscn"

@export var player_train: Train3D = null

func _enter_tree() -> void:
	SignalBus.player_entered_train.connect(Callable(self, "_on_train_entered"))
	SignalBus.player_exited_train.connect(Callable(self, "_on_train_exited"))

func on_trigger():
	super.on_trigger()
	self.show_transfer_inventory_diag()

func show_transfer_inventory_diag():
	var diag_scene: PackedScene = load(TRANSFER_INV_DIAG_SCENE)
	var diag_instance: InventoryTransferDialog = diag_scene.instantiate()
	$/root.add_child(diag_instance)
	diag_instance.show_dialog()

#region Callables
func _on_train_entered(train3d: Train3D):
	self.player_train = train3d

func _on_train_exited():
	self.player_train = null
#endregion
