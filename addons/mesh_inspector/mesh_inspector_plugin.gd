@tool
extends EditorInspectorPlugin
class_name MeshInspectorPlugin

func _can_handle(object: Object) -> bool:
	# Handle MeshInstance3D nodes or Mesh resources directly
	return object is MeshInstance3D or object is Mesh

func _parse_begin(object: Object):
	var control = MeshInspectorControl.new()
	control.object = object
	add_custom_control(control)
