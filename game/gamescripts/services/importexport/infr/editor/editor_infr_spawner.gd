## be careful - you can only run this script with the WorldMap (per exmaple MPSB) open
## do not try to run with the Empty "Worldscene" open
@tool
class_name EditorInfrSpawner extends EditorScript

func _run():
	self.clear_editor_tracks()
	self.spawn_track_paths()
	self.spawn_road_paths()

func clear_editor_tracks():
	var rail_container: Node = self.get_infr_container().find_child("EditorRails")
	for child: Node in rail_container.get_children(true):
		child.queue_free()
	var roads_container: Node = self.get_infr_container().find_child("EditorRails")
	for child: Node in roads_container.get_children(true):
		child.queue_free()

#region Infr Spawning
func spawn_track_paths():
	WorldTracksGenerator.new().spawn_track_paths()

func spawn_road_paths():
	WorldRoadsGenerator.new().spawn_road_paths()
#endregion

func get_infr_container() -> GeneratedInfrContainer:
	var infr_container = EditorInterface.get_edited_scene_root().find_child("EditorInfr", true)
	if ! infr_container: push_error("Cannt find Node \"EditorInfr\"")
	return infr_container as GeneratedInfrContainer
