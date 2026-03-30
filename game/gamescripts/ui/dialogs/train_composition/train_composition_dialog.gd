@warning_ignore("missing_tool")
class_name TrainCompositionDialog extends GameDialog

const VEHICLE_ROW_SCENE_PATH = "res://scenes/ui/dialogs/train_composition/vehicle_row.tscn"
const VEHICLE_SELECT_DIAG_SCENE = "res://scenes/ui/dialogs/select_vehicle/select_vehicle_dialog.tscn"

signal rows_updated(vehicle_row_dtos: TrainVehicleList)

@export var depot_num: int = 1
@export var vehicle_rows: TrainVehicleList = TrainVehicleList.new()

#region Initialization
func _init():
	super()
	self.dialog_key = "ComposeTrainDialog"

func _ready() -> void:
	# unlocke mouse from player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# clear pladeholder vehicle
	self.clear_list()
	# connect signals
	%AddVehicleBtn.pressed.connect(Callable(self, "_on_add_vehicle_btn_click"))
	self.vehicle_rows.updated.connect(Callable(self, "_on_vehicle_list_updated"))
	%OkButton.pressed.connect(Callable(self, "_on_spawn_btn_pressed"))
#endregion

func show_add_vehicle_diag():
	var diag_scene: PackedScene = load(VEHICLE_SELECT_DIAG_SCENE)
	var diag_instance: SelectVehicleDialog = diag_scene.instantiate()
	diag_instance.spawn_train = false
	diag_instance.hide_wagons = false
	# show dialog
	$/root.add_child(diag_instance)
	# connect to signal
	diag_instance.before_closed.connect(Callable(self, "_on_veh_selection_diag_closed"))

#region Add Vehicle
func clear_list():
	for child: Node in %VehiclesListLayout.get_children():
		if ! child is Label:
			child.queue_free()

func rebuild_list_items():
	self.clear_list()
	for train_veh: TrainVehicleDto in self.vehicle_rows.rows:
		# add VehicleRow element
		var veh_row: TrainCompositionVehicleRow = load(VEHICLE_ROW_SCENE_PATH).instantiate()
		veh_row.train_veh = train_veh
		veh_row.parent_list = self.vehicle_rows
		%VehiclesListLayout.add_child(veh_row)

func add_vehicle_row(veh_type_key: String):
	Loggie.info("check")
	# update row list
	var next_index: int = self.vehicle_rows.rows.size()
	var _train_veh: TrainVehicleDto = TrainVehicleDto.of(next_index, veh_type_key)
	self.vehicle_rows.append(_train_veh)
#endregion

#region Closing
func close():
	# disconnect signals
	if %AddVehicleBtn.pressed.is_connected(_on_add_vehicle_btn_click):
		%AddVehicleBtn.pressed.disconnect(_on_add_vehicle_btn_click)
	# close & destroy self
	self.diag_result = self.vehicle_rows
	self.close_self()
#endregion

#region Callbacks
func _on_add_vehicle_btn_click():
	self.show_add_vehicle_diag()

func _on_veh_selection_diag_closed(_diag_result):
	if _diag_result is String:
		var veh_type_key: String = _diag_result
		Loggie.info("Vehicle Selection closed with: %s" % veh_type_key)
		self.add_vehicle_row(veh_type_key)

func _on_vehicle_list_updated():
	Loggie.info("Vehicle list updated")
	self.rebuild_list_items()

func _on_spawn_btn_pressed():
	self.diag_result = self.vehicle_rows
	self.close_all()
#endregion
