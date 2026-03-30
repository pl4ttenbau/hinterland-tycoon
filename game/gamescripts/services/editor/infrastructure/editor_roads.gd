@icon("uid://dyg1oiarkflpi")
@tool
class_name GeneratedRoadWays extends Node3D

@export_tool_button("Generate Roadways")
var gen_tracks = Callable(self, "do_generate_roadways")

@export_tool_button("Clear Roads")
var clear_btn = Callable(self, "do_clear")

#region Actions
func do_generate_roadways():
	var generator := WorldRoadsGenerator.new()
	generator.spawn_road_paths()
	generator.queue_free()

func do_clear():
	self.clear()
#endregion

func add_road(line3d: EditorInfrLine3D):
	self.add_child(line3d)
	line3d.owner = EditorInterface.get_edited_scene_root()

func clear():
	for child in self.get_children():
		if child is Path3D: child.queue_free()
