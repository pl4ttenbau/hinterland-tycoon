class_name VehicleListUi extends MarginContainer

const ITEMS_SCENE_PATH = "res://scenes/ui/list/vehicle_list/vehicle_list_item.tscn"

signal vehicles_filtered()

@warning_ignore("unused_signal")
signal selection_changed(veh_type_key: String)

@export var all_vehicle_types: Array[VehicleTypeData] = []
@export var filtered: Array[VehicleTypeData] = []

@export var hide_wagons: bool = false:
	get(): return hide_wagons
	set(value):
		hide_wagons = value
		self.filter()

#region Initialization
func _enter_tree() -> void:
	self.vehicles_filtered.connect(Callable(self, "_on_vehicles_filtered"))
	SignalBus.dialog_vehicle_selection.connect(Callable(self, "_on_vehicle_selected"))

func _ready() -> void:
	self.load_vehicles()
	
func load_vehicles():
	self.all_vehicle_types = []
	for veh_type: VehicleTypeData in GameTypes.vehicle_types_dict.values():
		self.all_vehicle_types.append(veh_type)
	if ! self.all_vehicle_types || self.all_vehicle_types.size() == 0:
		Loggie.error("Cannot load vehicle type list")
		return
	self.filter()

func filter():
	self.filtered = []
	for veh_type: VehicleTypeData in self.all_vehicle_types:
		if !self.hide_wagons || veh_type.has_motor:
			self.filtered.append(veh_type)
	self.vehicles_filtered.emit()
#endregion

#region Instantization
func initialize_items():
	self.clear()
	# self.filter(self.hide_wagons)
	for veh_type: VehicleTypeData in self.filtered:
		self.add_item(self.build_veh_type_item(veh_type))
	
func build_veh_type_item(veh_type: VehicleTypeData) -> VehicleListItemUi:
	var item: VehicleListItemUi = load(ITEMS_SCENE_PATH).instantiate()
	item.veh_type_key = veh_type.key
	item.headline_text = veh_type.display_name
	return item
#endregion

#region Add & Remove Items
func clear():
	for child in %ItemsContainer.get_children():
		child.free()
		
func add_item(item: VehicleListItemUi):
	item.parent_list = self
	%ItemsContainer.add_child(item)
#endregion

#region Callbacks
func _on_vehicles_filtered():
	Loggie.info("Locomotive types loaded: %d of %d" % [self.filtered.size(), self.all_vehicle_types.size()])
	self.initialize_items()

func _on_vehicle_selected(veh_type_key: String):
	self.selection_changed.emit(veh_type_key)
#endregion
