@icon("res://assets/icons/icon_road.png")
class_name OuterRoad extends VisibleObject

@export var road: RoadData:
	set(value):
		self.entity = value
		self.get_path_3d().curve = value.curve
		self.assign_node_names()
	
func assign_node_names():
	var track_num: int = self.entity.num
	self.name = "Road_%d_Container" % track_num
	self.get_path_3d().name = "Road_%d_Path" % track_num
	self.get_road_mesh().name = "Road_%d_Mesh" % track_num

func get_path_3d() -> Path3D:
	return $"./RoadPath"
	
func get_road_mesh() -> PathMesh3D:
	return self.get_child(1)
	
func get_middle_pos() -> Vector3:
	var road_vertice_count: int = self.entity.vertices.size()
	var middle_index: int = floori(road_vertice_count /2)
	return self.entity.vertices.get(middle_index)
	
