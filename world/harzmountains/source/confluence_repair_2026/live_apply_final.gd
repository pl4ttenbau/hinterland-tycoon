@tool
extends Node
func _ready() -> void:
 if Engine.is_editor_hint():call_deferred("apply_repair")
func apply_repair() -> void:
 var terrain: Node = get_parent().get_node("WorldTerrain")
 var folder: String = "res://world/harzmountains/source/confluence_repair_2026"
 var records: Array = JSON.parse_string(FileAccess.get_file_as_string(folder+"/repair_regions.json"))
 for item: Dictionary in records:
  var loc := Vector2i(item.location[0],item.location[1])
  var r: Resource = terrain.data.get_region(loc)
  assert(r.get_height_map().get_data()==FileAccess.get_file_as_bytes(folder+"/"+item.file+".live.rf"),"Live terrain changed; repair aborted")
 for item: Dictionary in records:
  var loc := Vector2i(item.location[0],item.location[1])
  var r: Resource = terrain.data.get_region(loc)
  var control: PackedByteArray = r.get_control_map().get_data()
  var color: PackedByteArray = r.get_color_map().get_data()
  assert(ResourceSaver.save(r,folder+"/"+item.file+".before.res")==OK)
  var raw: PackedByteArray = FileAccess.get_file_as_bytes(folder+"/"+item.file+".fixed.rf")
  var image: Image = r.get_height_map()
  image.set_data(256,256,false,Image.FORMAT_RF,raw)
  r.set_height_map(image)
  r.calc_height_range()
  r.set_modified(true)
  var path: String = "res://world/harzmountains/heightdata/"+item.file
  assert(r.save(path,false)==OK)
  var reload: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
  assert(reload.get_height_map().get_data()==raw)
  assert(reload.get_control_map().get_data()==control and reload.get_color_map().get_data()==color)
 terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT,true,false)
 var report := FileAccess.open(folder+"/applied.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"live_applied":true,"height_reload_verified":true,"paint_unchanged":true,"regions":records.size()},"\t"))
 print("CONFLUENCE_REPAIR_APPLIED")
