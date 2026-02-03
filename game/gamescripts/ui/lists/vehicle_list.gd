class_name VehicleList extends MarginContainer

const ITEMS_SCENE_PATH = "res://scenes/ui/list/items/vehicle_list_item.tscn"

signal locomotives_loaded()

var locomotive_types: Array[VehicleTypeData] = []

#region Initialization
func _enter_tree() -> void:
	self.locomotives_loaded.connect(Callable(self, "_on_locomotives_loaded"))

func _ready() -> void:
	self.clear()
	self.load_locomotives()
	
func load_locomotives():
	var all_veh_types: Array = GameTypes.vehicle_types_dict.values()
	if ! all_veh_types || all_veh_types.size() == 0:
		Loggie.error("Cannot load vehicle type list")
		return
	for veh_type: VehicleTypeData in all_veh_types:
		if veh_type.has_motor:
			self.locomotive_types.append(veh_type)
	self.locomotives_loaded.emit()
#endregion

#region Instantization
func initialize_items():
	for loco_type: VehicleTypeData in self.locomotive_types:
		self.add_item(self.build_veh_type_item(loco_type))
	
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
func _on_locomotives_loaded():
	Loggie.info("Locomotive types loaded: %d" % self.locomotive_types.size())
	self.initialize_items()
#endregion
