class_name SelectVehicleDialog extends Control

const DEPOT_BOX_SCENE_PATH = "res://scenes/ui/depot_selection_box.tscn" 

@export var selected: String

signal vehicle_spawn_triggered(veh_type_key: String)

#region Initialization
func _ready() -> void:
	# unlock mouse
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	# bind signals
	%SpawnButton.pressed.connect(Callable(self, "_on_spawn_button_click"))
	SignalBus.dialog_vehicle_selection.connect(Callable(self, "_on_vehicle_selection_changed"))
	# initialize depot list
	self.add_depot_btns()
	
func add_depot_btns():
	for depot: RailDepotData in GlobalState.depots:
		self.add_depot_btn(depot)
		
func add_depot_btn(_depot: RailDepotData) -> DepotSelectionBox:
	var instance: DepotSelectionBox = load(DEPOT_BOX_SCENE_PATH).instantiate()
	instance.depot = _depot
	%DepotSelectionHLayout.add_child(instance)
	return instance
#endregion

#region Actions
func close():
	Loggie.info("Closing...")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# disconnect signals
	if %SpawnButton.pressed.is_connected(_on_spawn_button_click):
		%SpawnButton.pressed.disconnect(_on_spawn_button_click)
	if SignalBus.dialog_vehicle_selection.is_connected(_on_vehicle_selection_changed):
		SignalBus.dialog_vehicle_selection.disconnect(_on_vehicle_selection_changed)
	# remove
	self.queue_free()
#endregion

#region Callbacks
func _on_spawn_button_click():
	# trigger signal
	self.vehicle_spawn_triggered.emit(self.selected)
	# disconnect signals & close
	self.close()
	
func _on_vehicle_selection_changed(veh_type_key: String):
	self.selected = veh_type_key
#endregion
