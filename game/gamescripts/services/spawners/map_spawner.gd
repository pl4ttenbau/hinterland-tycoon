class_name MapSpawner extends Node

func _enter_tree() -> void:
	Managers.map_spawner = self
	SignalBus.map_selected.connect(Callable(self, "_on_map_selected"))

func _ready() -> void:
	self._on_map_selected(GlobalState.loaded_map)

func spawn_map(map_data: MapData):
	# finished
	var container = GlobalState.terrain
	SignalBus.map_spawned.emit(container)
	Loggie.info("Terrain has been spawned")

func _on_map_selected(map_obj: MapData):
	Loggie.info("Map Selected!")
	self.spawn_map(map_obj)
