class_name SelectVehicleDialog extends Control

@export var selected: String

signal vehicle_spawn_triggered(veh_type_key: String)

func _ready() -> void:
	# unlock mouse
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	# bind signals
	%SpawnButton.pressed.connect(Callable(self, "_on_spawn_button_click"))
	SignalBus.dialog_vehicle_selection.connect(Callable(self, "_on_vehicle_selection_changed"))

func close():
	Loggie.info("Closing...")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# trigger signal
	self.vehicle_spawn_triggered.emit(self.selected)
	# disconnect signals
	if %SpawnButton.pressed.is_connected(_on_spawn_button_click):
		%SpawnButton.pressed.disconnect(_on_spawn_button_click)
	if SignalBus.dialog_vehicle_selection.is_connected(_on_vehicle_selection_changed):
		SignalBus.dialog_vehicle_selection.disconnect(_on_vehicle_selection_changed)
	# remove
	self.queue_free()

func _on_spawn_button_click():
	self.close()
	
func _on_vehicle_selection_changed(veh_type_key: String):
	self.selected = veh_type_key
