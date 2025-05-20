class_name OuterRoad extends Node3D

@export var road: RoadWay

func set_road(_road: RoadWay):
	self.road = _road
	# rename name
	self.name = "Road_%d_Container" % _road.num
	# set names of children
	self.get_path_3d().name = "RailTrack_Path_%d" % _road.num
	self.get_rail_mesh().name = "RailTrack_Mesh_%d" % _road.num

func get_path_3d() -> Path3D:
	return self.get_child(0) as Path3D
	
func get_rail_mesh() -> PathMesh3D:
	return self.get_child(1)
