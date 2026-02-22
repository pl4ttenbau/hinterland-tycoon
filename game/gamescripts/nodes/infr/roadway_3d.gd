@icon("res://assets/icons/icon_road.png")
class_name RoadWay3D extends VisibleObject

@export var road: RoadData:
	set(value):
		self.entity = value
		self.position = value.start_pos
		self.get_path_3d().curve = value.curve
		self.assign_node_names()
	get(): return self.entity as RoadData
	
func assign_node_names():
	var track_num: int = self.entity.num
	self.name = "Road_%d_Container" % track_num
	self.get_path_3d().name = "Road_%d_Path" % track_num
	self.get_road_mesh().name = "Road_%d_Mesh" % track_num

func get_path_3d() -> Path3D:
	return self.get_child(0)
	
func get_road_mesh() -> PathMesh3D:
	return self.get_child(1)
