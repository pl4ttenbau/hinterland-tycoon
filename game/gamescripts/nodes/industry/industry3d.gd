@icon("res://assets/icons/nodes_3d/icon_industry.svg")
class_name Industry3D extends InventoryEntity3D

static var last_ind_num: int = 0

@export_storage var bld_num: int

@export var industry: IndustryData:
	get(): return self.entity as IndustryData
	set(value): 
		self.entity = value
		self.position = value.pos
		self._set_name(value)
		
@export var sign3d: IndustrySign3D

## Production, the info dialog and manual transfers use the same inventory.
func get_shared_inventory() -> GoodsInventory:
	if industry == null or industry.station_connection == null:
		return null
	var connection: StationIndustryConnection = industry.station_connection
	if connection.interchange != null:
		return connection.interchange.inventory
	# Standalone stations can still be connected by older callers.
	var stop_view: InventoryEntity3D = connection.station.get_inventory_view() if connection.station != null else null
	return stop_view.get_inventory() if is_instance_valid(stop_view) else null

#region Static Constructor
static func of(_industry: IndustryData) -> Industry3D:
	if ! _industry.ind_type:
		Loggie.error("cannot spawn industry! type \"%s\" unknown" % _industry.ind_type)
		return null
	var scene_path := _industry.ind_type.get_mesh_path()
	var packed_scene: PackedScene = load(scene_path)
	var instanciated: Industry3D = packed_scene.instantiate()
	instanciated.industry = _industry
	return instanciated
#endregion

#region Initialization
func _ready() -> void:
	self.spawn_industry_label()
	self.spawn_inventory_and_production()
	super._ready()

func spawn_industry_label() -> IndustrySign3D:
	return IndustrySign3D.of(self)

func spawn_inventory_and_production():
	if InventoryContainer.find_on(self) == null:
		var inventory_container: InventoryContainer = InventoryContainer.new()
		inventory_container.name = "Inventory"
		self.add_child(inventory_container)
	if !self.has_node("Production"):
		var production: IndustryProduction = IndustryProduction.new()
		production.industry3d = self
		self.add_child(production)
		production.name = "Production"
#endregion

#region Helper-Methods
func _set_name(ind_obj: IndustryData):
	var underscored: String = ind_obj.ind_name.replace(" ", "_")
	self.name = underscored
#endregion
