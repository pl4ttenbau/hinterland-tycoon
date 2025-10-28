class_name StartMenuMapSelection extends StartmenuSubscene

const CHILD_SCENE_PATH = "res://scenes/ui/startmenu/other_controls/map_selection_button.tscn"

@export var buttons_shown: bool = false

func _enter_tree() -> void:
	SignalBus.map_list_loaded.connect(Callable(self, "_on_map_list_loaded"))
	
func _ready() -> void:
	if ! self.buttons_shown:
		self.show_map_buttons()
	
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
	
#region Callbacks
func _on_map_selected(map_key: String):
	Loggie.info("Selected Map: %s" % map_key)
	
func _on_map_list_loaded(_maps: Array[MapData]):
	self.show_map_buttons()
#endregion
