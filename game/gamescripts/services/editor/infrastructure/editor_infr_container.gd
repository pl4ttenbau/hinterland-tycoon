@tool
class_name EditorInfrContainer extends Node

@export_group("Infr. Actions")
@export_tool_button("Empty Infr.")
var empty_infr = Callable(self, "do_empty_infr")

func _ready() -> void:
	if Engine.is_editor_hint():
		self.owner = EditorInterface.get_edited_scene_root()

func add_rail(line3d: EditorInfrLine3D, _owner):
	$EditorRails.add_child(line3d)
	line3d.owner = _owner

func add_road(line3d: EditorInfrLine3D, _owner):
	$EditorRoads.add_child(line3d)
	line3d.owner = _owner
	
#region Button Action
func do_empty_infr() -> void:
	for child in $EditorRails.get_children():
		if child is Path3D: child.queue_free()
	for child in $EditorRails.get_children():
		if child is Path3D: child.queue_free()
#endregion
