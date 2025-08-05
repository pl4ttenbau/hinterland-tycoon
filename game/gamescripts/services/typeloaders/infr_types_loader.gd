class_name InfrTypesLoader extends AbstractGameTypeLoader

func _init() -> void:
	self.make_types()

static func make_types() -> Array[InfrType]:
	var infr_types: Array[InfrType] = []
	# create objects and append
	infr_types.append(InfrType.new(0, "750_MM", true, "res://scenes/subscenes/infr/rail_path_mesh_3d.tscn"))
	infr_types.append(InfrType.new(1, "NORMAL_GAUGE", true, "res://scenes/subscenes/infr/rail_path_mesh_3d.tscn"))
	infr_types.append(InfrType.new(2, "RURAL_ROAD", false, "res://scenes/subscenes/infr/road_path_mesh_3d.tscn"))
	
	if GameTypes.infr_types != null:
		Loggie.warn("Overwriting already generated infrastructure types")
	GameTypes.infr_types = infr_types
	# all done
	return infr_types
