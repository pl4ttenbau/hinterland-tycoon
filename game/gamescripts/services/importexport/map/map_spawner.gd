@icon("res://assets/icons/icon_map_white.png")
class_name MapSpawner extends Node

@export var terrain_container: WorldMapScene

func spawn_map(map_data: MapData):
	if not Managers.are_world_services_initialized() or Managers.map_spawner != self:
		push_error("Cannot spawn a map before world services are initialized")
		return
	var tscn_path := map_data.get_scene_file_path()
	Loggie.info("Loading map scene from %s" % tscn_path)
	if ResourceLoader.exists(tscn_path):
		var packed_scene: PackedScene = ResourceLoader.load(tscn_path)
		self.register_scene(packed_scene.instantiate())
	
func place_terrain_scene(_terrain_container: WorldMapScene):
	self.add_child(_terrain_container)
	
func register_scene(instanciated_scene: WorldMapScene):
	# This is a runtime instance; the saved editor scene remains untouched.
	var editor_objects: Node = instanciated_scene.get_node_or_null("EditorObjects")
	if editor_objects:
		editor_objects.free()
	self.terrain_container = instanciated_scene
	self.place_terrain_scene(instanciated_scene)
	# finished
	Loggie.info("Terrain has been spawned")
	SignalBus.map_spawned.emit(self.terrain_container)

func _on_map_selected(map_obj: MapData):
	Loggie.info("Map Selected!")
	self.spawn_map(map_obj)
