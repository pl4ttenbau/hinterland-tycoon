@icon("res://assets/icons/icon_deco_white.png")
class_name DecoSpawner extends Node

const DECO_FILEPATH_FORMAT := "res://world/%s/jsondata/decoration.json"

@export var splines: Array[DecoSplineData] = []
@export var static_objs: Array[DecoObjectData] = []

@export var outer_splines: Array[OuterDecoSpline] = []

func _enter_tree() -> void:
	Managers.deco = self
	SignalBus.map_spawned.connect(Callable(self, "_on_world_spawned"))
	
func _ready() -> void:
	self.load_static_deco()
	self.load_deco_splines()
	Loggie.info("deco precreated")
	
func load_static_deco():
	pass

#region Deco Splines
func load_deco_splines():
	var json_path = DECO_FILEPATH_FORMAT % GlobalState.selected_map_name
	var json_str: String = FileAccess.get_file_as_string(json_path)
	for spline_dict in JSON.parse_string(json_str).splines:
		Loggie.info(spline_dict)
		self.splines.append(DecoSplineData.from_dict(spline_dict))
	
func spawn_deco_splines():
	for spline_obj in self.splines:
		var outer_spline := spline_obj.spawn()
		self.outer_splines.append(outer_spline)
		self.add_child(outer_spline)
#endregion	

#region Event Callbacks
func _on_world_spawned(_container: TerrainContainer):
	spawn_deco_splines()
#endregion
