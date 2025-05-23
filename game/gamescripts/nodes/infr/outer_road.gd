class_name OuterRoad extends Node3D

@export var road: RoadWay

func set_road(_road: RoadWay):
	self.road = _road
	self.get_path_3d().curve = _road.curve
	# rename name
	self.name = "Road_%d_Container" % _road.num
	# set names of children
	self.get_path_3d().name = "Road_%d_Path" % _road.num
	self.get_road_mesh().name = "Road_%d_Mesh" % _road.num

func get_path_3d() -> Path3D:
	return self.get_child(0) as Path3D
	
func get_road_mesh() -> PathMesh3D:
	return self.get_child(1)
