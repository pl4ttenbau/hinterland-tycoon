## Every curve-based infrastructure piece (rail track, road) inherits from this.
## Curves are in world coordinates.
@tool
@abstract
class_name AbstractTrack extends GameEntityData

@warning_ignore("unused_signal")
signal track_changed()

@warning_ignore("unused_signal")
signal curve_built(curve3d: Curve3D)

## z.B. "Rübeländer Landstr." oder "MPSB Friedland Kurve"
@export_storage var track_name: String

## z.B. "A20" oder "ALKB"
@export var tag: String

## global pos of the first node
@export var start_pos: Vector3

@export var center: Vector3:
	get(): return _get_center()

# infr type
@export var infr_type_key: String

# curve; nodes live in the typed array of each subclass
@export var curve: Curve3D

#region Nodes
## Subclasses keep their own typed node array; typed arrays cannot be shared.
@abstract func get_nodes() -> Array

func node_count() -> int:
	return self.get_nodes().size()

func has_node_index(index: int) -> bool:
	return index >= 0 and index < self.node_count()

func get_node_at(index: int) -> AbstractInfrNode:
	return self.get_nodes()[index] if self.has_node_index(index) else null

func first_node() -> AbstractInfrNode:
	return self.get_node_at(0)

func last_node() -> AbstractInfrNode:
	return self.get_node_at(self.node_count() - 1)

func add_node(node: AbstractInfrNode, update: bool = false) -> void:
	self.get_nodes().append(node)
	if update:
		self.build_curve()
		self.track_changed.emit()
#endregion

#region Curve
func build_curve() -> void:
	self.curve = Curve3D.new()
	self.curve.up_vector_enabled = self._curve_up_vector_enabled()
	# add points to curve (optionally with curve handles)
	for node: AbstractInfrNode in self.get_nodes():
		self.curve.add_point(node.position, node.handle_in, node.handle_out)
	self._adjust_curve_handles(self.curve)
	if self._smooths_curve():
		InfrUtils.smooth_curve3d(self.curve, true)
	# Consumers must receive the finished curve, including its generated handles.
	self.curve_built.emit(self.curve)

func _curve_up_vector_enabled() -> bool:
	return false

func _smooths_curve() -> bool:
	return true

## Runs after the authored points are added and before smoothing.
func _adjust_curve_handles(_built: Curve3D) -> void:
	pass

func ensure_curve() -> Curve3D:
	if self.curve == null:
		self.build_curve()
	return self.curve

## Baked curve length in metres.
func length() -> float:
	return self.ensure_curve().get_baked_length()

## Distance of a node along the curve, or -1 for an invalid index.
## Endpoints are exact, so coincident start/end positions on a loop stay apart.
func node_offset(index: int) -> float:
	if not self.has_node_index(index):
		return -1.0
	if index == 0:
		return 0.0
	if index == self.node_count() - 1:
		return self.length()
	return self.ensure_curve().get_closest_offset(self.get_node_at(index).position)

## World position at a distance along the curve.
func position_at(offset: float) -> Vector3:
	return self.ensure_curve().sample_baked(clampf(offset, 0.0, self.length()))
#endregion

#region Getter-Methods
## Midpoint between the end nodes, not the middle of the curve.
func _get_center() -> Vector3:
	if self.node_count() <= 1: return Vector3.ZERO
	return self.first_node().position.lerp(self.last_node().position, .5)

func get_start_pos() -> Vector3:
	return self.first_node().position

func get_end_pos() -> Vector3:
	return self.last_node().position
#endregion
