class_name SelectVehicleDialog extends Control

const DEPOT_BOX_SCENE_PATH = "res://scenes/ui/ingame/entity_items/depot_selection_box.tscn" 

@export var selected_vehicle_type: String

@export var selected_depot_num: int

signal vehicle_spawn_triggered(spawn_dto: VehicleSpawnDto)

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
	# connect to signal
	instance.depot_selected.connect(Callable(self, "_on_depot_selection_changed"))
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
	var spawn_dto := VehicleSpawnDto.new(self.selected_vehicle_type, 
		self.selected_depot_num)
	self.vehicle_spawn_triggered.emit(spawn_dto)
	# disconnect signals & close
	self.close()
	
func _on_vehicle_selection_changed(veh_type_key: String):
	self.selected_vehicle_type = veh_type_key
	
func _on_depot_selection_changed(depot: RailDepotData):
	Loggie.info("Selected Depot: %d" % depot.num)
	self.selected_depot_num = depot.num
#endregion
