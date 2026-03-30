class_name VehicleList extends MarginContainer

const ITEMS_SCENE_PATH = "res://scenes/ui/list/items/vehicle_list_item.tscn"

signal vehicles_loaded()

@export var vehicle_types: Array[VehicleTypeData] = []

@export var hide_wagons: bool = true:
	get(): return hide_wagons
	set(value):
		hide_wagons = value
		self.load_vehicles()

#region Initialization
func _enter_tree() -> void:
	self.vehicles_loaded.connect(Callable(self, "_on_vehicles_loaded"))

func _ready() -> void:
	self.load_vehicles()
	
func load_vehicles():
	var all_veh_types: Array = GameTypes.vehicle_types_dict.values()
	if ! all_veh_types || all_veh_types.size() == 0:
		Loggie.error("Cannot load vehicle type list")
		return
	for veh_type: VehicleTypeData in all_veh_types:
		if (!self.hide_wagons || veh_type.has_motor):
			self.vehicle_types.append(veh_type)
	self.vehicles_loaded.emit()
#endregion

#region Instantization
func initialize_items():
	self.clear()
	for veh_type: VehicleTypeData in self.vehicle_types:
		self.add_item(self.build_veh_type_item(veh_type))
	
func build_veh_type_item(veh_type: VehicleTypeData) -> VehicleListItem:
	var item: VehicleListItem = load(ITEMS_SCENE_PATH).instantiate()
	item.veh_type_key = veh_type.key
	item.headline_text = veh_type.display_name
	return item
#endregion

#region Add & Remove Items
func clear():
	for child in %ItemsContainer.get_children():
		child.free()
		
func add_item(item: VehicleListItem):
	%ItemsContainer.add_child(item)
#endregion

#region Callbacks
func _on_vehicles_loaded():
	Loggie.info("Locomotive types loaded: %d" % self.vehicle_types.size())
	self.initialize_items()
#endregion
