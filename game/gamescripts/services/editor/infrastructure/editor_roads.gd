@icon("uid://dyg1oiarkflpi")
@tool
class_name GeneratedRoadWays extends Node3D

@export_tool_button("Generate Roadways")
var gen_tracks = Callable(self, "do_generate_roadways")

func do_generate_roadways():
	var generator := WorldRoadsGenerator.new()
	generator.spawn_road_paths()
	generator.queue_free()

func add_road(line3d: EditorInfrLine3D):
	self.add_child(line3d)
	line3d.owner = EditorInterface.get_edited_scene_root()
