## View of a curve-based line (rail track or road); never used directly.
## Child 0 is the Path3D. The PathMesh3D children repeat their tile along it.
## Line curves are in world coordinates, so these views sit at the world origin.
@abstract
class_name InfrLine3D extends GameEntity3D

## The curve shown; the same Curve3D object as the line's model curve.
@export var curve: Curve3D:
	get(): return self.get_path_3d().curve
	set(value): self.get_path_3d().curve = value

## The shown line as its shared base type; subclasses also expose a typed property.
func get_line() -> AbstractInfrLine:
	return self.entity as AbstractInfrLine

## Shows a line and follows its curve rebuilds from now on.
func bind_line(line: AbstractInfrLine) -> void:
	var previous: AbstractInfrLine = self.get_line()
	if previous != null and previous.curve_built.is_connected(self._on_curve_built):
		previous.curve_built.disconnect(self._on_curve_built)
	self.entity = line
	self._show_curve(line.curve)
	if not line.curve_built.is_connected(self._on_curve_built):
		line.curve_built.connect(self._on_curve_built)
	self.assign_node_names()

## Fit short sections before the path changes, so the meshes never warp a too-long tile.
func _show_curve(shown: Curve3D) -> void:
	for path_mesh: PathMesh3D in self.get_path_meshes():
		InfrUtils.fit_short_path_mesh(path_mesh, shown)
	self.curve = shown

func _on_curve_built(built: Curve3D) -> void:
	self._show_curve(built)

#region Node names
## e.g. "Road" names the nodes Road_12_Container and Road_12_Path.
@abstract func _name_prefix() -> String

func assign_node_names() -> void:
	var num: int = self.entity.num
	var prefix: String = self._name_prefix()
	self.name = "%s_%d_Container" % [prefix, num]
	self.get_path_3d().name = "%s_%d_Path" % [prefix, num]
	self._assign_mesh_names(prefix, num)

## Subclasses name their PathMesh3D children here.
func _assign_mesh_names(_prefix: String, _num: int) -> void:
	pass
#endregion

#region Children
func get_path_3d() -> Path3D:
	return self.get_child(0)

func get_path_meshes() -> Array[PathMesh3D]:
	var result: Array[PathMesh3D] = []
	for child: Node in self.get_children():
		if child is PathMesh3D:
			result.append(child)
	return result
#endregion
