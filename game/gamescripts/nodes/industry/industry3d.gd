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
		
#region Initialization
static func of(_industry: IndustryData) -> Industry3D:
	if ! _industry.ind_type:
		Loggie.error("cannot spawn industry! type \"%s\" unknown" % _industry.ind_type)
		return null
	var scene_path := _industry.ind_type.get_mesh_path()
	var instanciated: Industry3D = load(scene_path).instantiate()
	instanciated.industry = _industry
	return instanciated

func _ready() -> void:
	super._ready()
	self.spawn_industry_label()
	
func spawn_industry_label() -> IndustrySign3D:
	return IndustrySign3D.of(self)
#endregion

#region Production

#endregion
	
#region Callbacks

#endregion

#region Helper-Methods
func _set_name(ind_obj: IndustryData):
	var underscored: String = ind_obj.ind_name.replace(" ", "_")
	self.name = underscored
#endregion
