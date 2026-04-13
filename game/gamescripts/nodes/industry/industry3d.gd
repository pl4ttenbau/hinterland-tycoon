@icon("res://assets/icons/icon_industry.png")
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
	if !self.has_node("Inventory"):
		var inventory_container: InventoryContainer = InventoryContainer.new()
		inventory_container.inventory = GoodsInventory.new()
		self.add_child(inventory_container)
		inventory_container.name = "Inventory"
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
