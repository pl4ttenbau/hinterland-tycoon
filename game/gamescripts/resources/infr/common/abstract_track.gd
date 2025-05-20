class_name AbstractTrack extends Node3D

@export var vertices: Array[Vector3] = []
@export var curve: Curve3D
@export_storage var num: int

func build_path() -> void:
	# if self.curve: return
	self.curve = Curve3D.new()
	for point: Vector3 in self.vertices:
		self.curve.add_point(point)
