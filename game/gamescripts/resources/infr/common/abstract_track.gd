## every curve based infrastructure pieve should inherit from this
@tool
class_name AbstractTrack extends GameObject

@export_storage var track_name: String

## global pos of the first node
@export var start_pos: Vector3

# infr type
@export var infr_type_key: String

# curve & nodes
@export var curve: Curve3D
@export var vertices: Array[Vector3] = []
