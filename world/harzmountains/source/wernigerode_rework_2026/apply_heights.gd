extends SceneTree
func _init() -> void:
 call_deferred("run")
func run() -> void:
 var folder: String = "/home/cornelinux/.godotproj/hinterland-tycoon/world/harzmountains/source/wernigerode_rework_2026"
 var records: Array = JSON.parse_string(FileAccess.get_file_as_string(folder+"/terrain_to_apply.json"))
 for item: Dictionary in records:
  var path: String = "res://heightdata/"+item.file
  assert(FileAccess.get_sha256(path)==item.sha256)
  var region: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
  var control: PackedByteArray = region.get_control_map().get_data()
  var color: PackedByteArray = region.get_color_map().get_data()
  var raw: PackedByteArray = FileAccess.get_file_as_bytes(folder+"/"+item.file+".rf")
  var backup: String = folder+"/"+item.file+".before"
  assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),backup)==OK)
  var image: Image = region.get_height_map()
  image.set_data(256,256,false,Image.FORMAT_RF,raw)
  region.set_height_map(image)
  region.set_location(Vector2i(item.location[0],item.location[1]))
  region.calc_height_range()
  region.set_modified(true)
  assert(region.save(path,false)==OK)
  var check: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
  assert(check.get_height_map().get_data()==raw)
  assert(check.get_control_map().get_data()==control)
  assert(check.get_color_map().get_data()==color)
 print("TERRAIN_VERIFIED_REGIONS ",records.size())
 quit()
