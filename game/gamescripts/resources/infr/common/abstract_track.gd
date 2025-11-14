## every curve based infrastructure pieve should inherit from this
@tool
class_name AbstractTrack extends GameObject

@export var infr_type_key: String
@export_storage var track_name: String
@export var vertices: Array[Vector3] = []
@export var curve: Curve3D
@export var offset: Vector3
