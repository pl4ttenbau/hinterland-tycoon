## every curve based infrastructure pieve should inherit from this
@tool
class_name AbstractTrack extends GameObject

@export_storage var track_name: String

## global pos of the first node
@export var start_pos: Vector3

@export var center: Vector3:
	get(): return _get_center()

# infr type
@export var infr_type_key: String

# curve & nodes
@export var curve: Curve3D
@export var vertices: Array[Vector3] = []

#region Getter-Methods
func _get_center() -> Vector3:
	if !self.vertices || self.vertices.size() <= 1: return Vector3.ZERO
	var left_top: Vector3 = self.vertices[0]
	var right_bottom: Vector3 = self.vertices[self.vertices.size() -1]
	return left_top.lerp(right_bottom, .5)
#endregion
