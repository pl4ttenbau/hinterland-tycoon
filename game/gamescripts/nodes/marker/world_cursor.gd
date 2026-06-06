@tool
@icon("res://assets/icons/icon_mouse_3d.png")
class_name WorldCursor3D extends Marker3D

@export_tool_button("Put On Ground")
var put_on_ground = Callable(self, "_do_put_on_ground")

#region Tool Actions
func _do_put_on_ground():
	var height: float = EditorUtils.get_y_at_pos(self.global_position)
	self.global_position.y = height
#endregion
