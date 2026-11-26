@tool
extends Node
func _ready() -> void:
 if Engine.is_editor_hint():call_deferred("export_live")
func export_live() -> void:
 var terrain: Node = get_parent().get_node("WorldTerrain")
 var folder: String = "res://world/harzmountains/source/confluence_repair_2026"
 var rows: Array = []
 for region: Resource in terrain.data.get_regions_active():
  var loc: Vector2i = region.get_location()
  if loc.x<11 or loc.x>12 or loc.y<5 or loc.y>6:continue
  var name: String = "terrain3d_%02d_%02d.res" % [loc.x,loc.y]
  var f := FileAccess.open(folder+"/"+name+".live.rf",FileAccess.WRITE)
  f.store_buffer(region.get_height_map().get_data())
  rows.append({"file":name,"location":[loc.x,loc.y]})
 var out := FileAccess.open(folder+"/live_inputs.json",FileAccess.WRITE)
 out.store_string(JSON.stringify(rows,"\t"))
 var waters: Array = []
 for node: Node in terrain.get_node("Water").find_children("*","MeshInstance3D",true,false):
  if node.mesh is PlaneMesh:
   var t: Transform3D = node.global_transform
   waters.append({"name":node.name,"origin":[t.origin.x,t.origin.y,t.origin.z],"basis_x":[t.basis.x.x,t.basis.x.y,t.basis.x.z],"basis_z":[t.basis.z.x,t.basis.z.y,t.basis.z.z],"size":[node.mesh.size.x,node.mesh.size.y]})
 var wf := FileAccess.open(folder+"/live_water.json",FileAccess.WRITE)
 wf.store_string(JSON.stringify(waters,"\t"))
 print("REPAIR_LIVE_EXPORTED ",rows.size())
