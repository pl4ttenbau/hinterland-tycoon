class_name StartmenuRoot extends Control

const INITIAL_SCENE_NAME = "root_buttons"
const SUB_SCENE_FOLDER = "res://scenes/ui/startmenu/subscenes/"

@export var current_menu: StartmenuSubscene = null 

#region Initialization
func _init() -> void:
	UiState.main_menu_root = self

func _enter_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	self.load_menu(INITIAL_SCENE_NAME)
#endregion

func _exit_tree() -> void:
	UiState.in_main_menu = false
	UiState.main_menu_root = null
	UiState.main_menu_scene = null
	# capture mouse again
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func close() -> void:
	self.queue_free()

func load_menu(subscene_name: String) -> void:
	if self.current_menu != null:
		self.unload_current()
	var scene_file_name: String = "startmenu_%s.tscn" % subscene_name
	var scene_path: String = SUB_SCENE_FOLDER + scene_file_name
	var scene_res: PackedScene = load(scene_path)
	self.spawn_submenu(scene_res.instantiate())
	
func unload_current():
	self.current_menu.queue_free()
	
func spawn_submenu(submenu: StartmenuSubscene):
	UiState.main_menu_scene = submenu
	submenu.startmenu_root = self
	%SubsceneContainer.add_child(submenu)
	self.current_menu = submenu
