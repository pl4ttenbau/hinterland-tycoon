extends SceneTree
func _init() -> void:
 call_deferred("run")
func run() -> void:
 var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://world/harzmountains/jsondata/roads.json"))
 var validator: GDScript = load("res://addons/hinterland_tools/infr/infr_line_validator.gd")
 assert(validator.validate_records(roads).is_empty())
 var mapper: GDScript = load("res://game/gamescripts/services/typeloaders/mappers/road_mapper.gd")
 for r: Dictionary in roads:
  var road: Resource = mapper.road_from_data_json(r)
  var c: Curve3D = road.ensure_curve()
  assert(c.point_count>=2)
 var reference: PackedScene = load("res://world/harzmountains/mapscenes/editorobjects_harzmountains.tscn")
 var world: PackedScene = load("res://world/harzmountains/mapscenes/world_harzmountains.tscn")
 assert(reference!=null and world!=null)
 var inter: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://world/harzmountains/jsondata/interchanges.json"))
 assert(inter is Array)
 print("HARZ_LAYOUT_VALIDATED roads=",roads.size()," reference_scene=OK world_scene=OK stops=OK")
 quit()
