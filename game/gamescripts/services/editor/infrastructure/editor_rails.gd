@icon("uid://c1dv0p5hgw68n")
@tool
class_name GeneratedRailLines extends Node3D

@export_tool_button("Generate Rail Tracks")
var gen_tracks_btn = Callable(self, "do_generate_rail_tracks")

@export_tool_button("Clear Rail Tracks")
var clear_btn = Callable(self, "do_clear")

#region Actions
func do_generate_rail_tracks():
	var generator := WorldTracksGenerator.new()
	generator.spawn_track_paths()
	generator.queue_free()
	
func do_clear():
	self.clear()
#endregion

func clear():
	for child in self.get_children():
		if child is Path3D: child.queue_free()

func add_rail(line3d: EditorInfrLine3D):
	self.add_child(line3d)
	line3d.owner = EditorInterface.get_edited_scene_root()
