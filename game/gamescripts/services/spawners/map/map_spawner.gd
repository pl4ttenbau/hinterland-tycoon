class_name MapSpawner extends Node

@export var terrain_container: WorldMapScene

func _enter_tree() -> void:
	Managers.map_spawner = self
	SignalBus.map_selected.connect(Callable(self, "_on_map_selected"))

func spawn_map(map_data: MapData):
	var tscn_path := map_data.get_scene_file_path()
	Loggie.info("Loading map scene from %s" % tscn_path)
	if ResourceLoader.exists(tscn_path):
		self.load_map_sync(tscn_path)

func load_map_sync(tscn_path: String):
	var packed_scene: PackedScene = ResourceLoader.load(tscn_path)
	self.register_scene(packed_scene.instantiate())

func load_map_async(tscn_path: String):
	var loader = AsyncScene.new(
		tscn_path,
		AsyncScene.LoadingOperation.Replace,
		$Terrain/Placeholder
	)
	loader.OnComplete.connect(self, "_on_loading_complete")
	loader.OnError.connect(self, "_on_loading_error")
	loader.start()

func register_scene(instanciated_scene: WorldMapScene):
	self.terrain_container = instanciated_scene
	$"./Terrain".add_child(instanciated_scene)
	# finished
	Loggie.info("Terrain has been spawned")
	SignalBus.map_spawned.emit(self.terrain_container)

#region Callbacks
func _on_map_selected(map_obj: MapData):
	Loggie.info("Map Selected!")
	self.spawn_map(map_obj)
	
func _on_loading_complete(_inst: AsyncScene):
	Loggie.info("SCENE LOADED")
	
func _on_loading_error(_err_code: AsyncScene.ErrorCode, err_message: String):
	Loggie.error("Map loading error: %s" % err_message)
#endregion
