## Scenes for Deco Splines must be in a subfolder of the "meshes/deco"-folder and
## named <spline_key>_spline.tscn
@icon("res://assets/icons/icon_deco.png")
class_name OuterDecoSpline extends VisibleObject

@export var spline: DecoSplineData:
	get(): return self.entity
	set(value): 
		self.entity = value
		self._build_curve()
	
@export var curve: Curve3D:
	set(value): 
		curve = value
		$PathMesh3D/Path3D.curve = value

func _build_curve():
	var temp_curve: Curve3D = Curve3D.new()
	for point: Vector3 in self.spline.points:
		temp_curve.add_point(point)
	self.curve = temp_curve
