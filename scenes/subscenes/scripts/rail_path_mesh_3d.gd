class_name RailTrackContainer extends Node3D

@export var rail_track: RailTrack

func set_track(_track: RailTrack):
	self.rail_track = _track
	_track.container = self
	# rename name
	self.name = "RailTrack_%d_Container" % _track.num
	# set names of children
	self.get_child(0).name = "RailTrack_Path_%d" % _track.num
	self.get_child(1).name = "RailTrack_Mesh_%d" % _track.num

func get_path_3d() -> Path3D:
	return self.get_child(0) as Path3D
