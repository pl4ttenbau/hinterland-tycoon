class_name SelectVehicleDialog extends GameDialog

const DEPOT_BOX_SCENE_PATH = "res://scenes/ui/ingame/entity_items/depot_selection_box.tscn" 

signal vehicle_spawn_triggered(spawn_dto: VehicleSpawnDto)

@export var hide_wagons: bool = true:
	get(): return hide_wagons
	set(value):
		hide_wagons = value
		%VehicleList.hide_wagons = value

@export var spawn_train: bool = true

@export var selected_vehicle_type: String

@export var selected_depot_num: int = -1:
	set(value):
		Loggie.info("Depot selected: %d" % value)
		selected_depot_num = value

#region Initialization
func _init():
	super()
	self.dialog_key = "SelectVehicleDialog"

func _ready() -> void:
	# unlock mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# bind signals
	%SpawnButton.button_down.connect(Callable(self, "_on_spawn_button_click"))
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
	# disconnect signals
	if %SpawnButton.pressed.is_connected(_on_spawn_button_click):
		%SpawnButton.pressed.disconnect(_on_spawn_button_click)
	if SignalBus.dialog_vehicle_selection.is_connected(_on_vehicle_selection_changed):
		SignalBus.dialog_vehicle_selection.disconnect(_on_vehicle_selection_changed)
	# remove
	super.close_self()
	self.queue_free()
#endregion

#region Callbacks
func _on_spawn_button_click():
	if self.spawn_train:
		# trigger signal
		var spawn_dto := VehicleSpawnDto.new(self.selected_vehicle_type, 
			self.selected_depot_num)
		self.vehicle_spawn_triggered.emit(spawn_dto)
	# disconnect signals & close
	self.close()
	
func _on_vehicle_selection_changed(veh_type_key: String):
	self.selected_vehicle_type = veh_type_key
	# save as close result
	self.diag_result = veh_type_key
	
func _on_depot_selection_changed(depot: RailDepotData):
	self.selected_depot_num = depot.num
#endregion
