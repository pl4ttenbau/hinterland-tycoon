class_name StartMenuRootButtons extends StartmenuSubscene

const SCENE_NAME_MAP_SELECTION = "map_selection"

func _ready() -> void:
	# connect buttons to signals
	%BtnNewGame.pressed.connect(Callable(self, "_on_new_game_click"))
	%BtnLoadGame.pressed.connect(Callable(self, "_on_load_game_click"))
	%BtnSettings.pressed.connect(Callable(self, "_on_settings_click"))
	%BtnExit.pressed.connect(Callable(self, "_on_exit_click"))
	
#region Callbacks
func _on_new_game_click():
	self.startmenu_root.load_menu(SCENE_NAME_MAP_SELECTION)
	
func _on_load_game_click():
	pass
	
func _on_settings_click():
	get_tree().quit()
	
func _on_exit_click():
	$/root.queue_free()
#endregion
