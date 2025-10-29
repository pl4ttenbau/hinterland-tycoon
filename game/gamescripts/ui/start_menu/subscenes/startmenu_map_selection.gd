class_name StartMenuMapSelection extends StartmenuSubscene

const CHILD_SCENE_PATH = "res://scenes/ui/startmenu/other_controls/map_selection_button.tscn"

@export var buttons_shown: bool = false

#region Initialization
func _enter_tree() -> void:
	SignalBus.map_list_loaded.connect(Callable(self, "_on_map_list_loaded"))
	
func _ready() -> void:
	if ! self.buttons_shown:
		self.show_map_buttons()
#endregion
	
#region Map Button Spawning
func show_map_buttons():
	if ! GlobalState.game_maps || GlobalState.game_maps.size() <= 0:
		Loggie.error("Cannot show map list; no maps loaded")
	for map_data: MapData in GlobalState.game_maps:
		self.add_map_button(map_data)
	self.buttons_shown = true
		
func add_map_button(map_data: MapData):
	var map_btn: MapSelectionButton = load(CHILD_SCENE_PATH).instantiate()
	map_btn.map_data = map_data
	# connect signal
	map_btn.pressed.connect(Callable(self, "_on_map_selected"))
	# add as child
	%VLayout.add_child(map_btn)
#endregion
	
func start_selected_map(map_key: String):
	GlobalState.selected_map_name = map_key
	GlobalState.loaded_map = self._get_map_obj_by_key(map_key)
	# close menu
	UiState.main_menu_root.unload_current()
	UiState.main_menu_root.close()
	# start map
	SignalBus.map_selected.emit(GlobalState.loaded_map)
	
func _get_map_obj_by_key(map_key: String) -> MapData:
	for map_data: MapData in GlobalState.game_maps:
		if map_data.key == map_key: return map_data
	Loggie.error("Map \"%s\" could not be found" % map_key)
	return null
	
#region Callbacks
func _on_map_selected(map_key: String):
	Loggie.info("Selected Map: %s" % map_key)
	self.start_selected_map(map_key)
	
func _on_map_list_loaded(_maps: Array[MapData]):
	self.show_map_buttons()
#endregion
