@tool
extends EditorPlugin

const STATE_AUTOLOAD_NAME = "EditorState"
const EDITOR_SIGNALS_SCRIPT = preload("res://addons/hinterland_tools/editor_signals.gd")

var editor_signals: Node
var map_panel: HBoxContainer
var build_town_button: Button
var active_world: WorldMapScene

func _enable_plugin() -> void:
	# Add autoloads here.
	if Engine.is_editor_hint():
		get_tree().root.tree_entered.connect(Callable(self, "_on_root_scene_node_added"))

func _disable_plugin() -> void:
	# Remove autoloads here.
	# disconnect signals
	if Engine.is_editor_hint():
		get_tree().root.tree_entered.disconnect(Callable(self, "_on_root_scene_node_added"))

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	print("HinterlandTycoon plugin activated!")
	# Keep editor events on the plugin, whose lifetime spans edited scenes.
	self.editor_signals = EDITOR_SIGNALS_SCRIPT.new()
	self.editor_signals.name = "EditorSignals"
	self.add_child(self.editor_signals)
	self.map_panel = HBoxContainer.new()
	self.build_town_button = Button.new()
	self.build_town_button.text = "Build Town"
	self.build_town_button.toggle_mode = true
	self.build_town_button.tooltip_text = "Select terrain-click mode for town placement."
	self.map_panel.add_child(self.build_town_button)
	self.add_control_to_bottom_panel(self.map_panel, "HinterlandTycoon")
	self.scene_changed.connect(self._on_scene_changed)
	# Receive viewport input even when no node handled by this plugin is selected.
	self.set_input_event_forwarding_always_enabled()
	# The plugin may be enabled after a map is already open.
	self._on_scene_changed(EditorInterface.get_edited_scene_root())
	self.enable_editor_state()

func _exit_tree() -> void:
	print("Deactivating HinterlandTycoon plugin")
	self._disconnect_world()
	self.scene_changed.disconnect(self._on_scene_changed)
	self.remove_control_from_bottom_panel(self.map_panel)
	self.map_panel.queue_free()
	self.remove_editor_state()

#region EditorState
func enable_editor_state():
	if ! Engine.has_singleton(STATE_AUTOLOAD_NAME):
		add_autoload_singleton(STATE_AUTOLOAD_NAME, "res://addons/hinterland_tools/editor_state.gd")

func remove_editor_state():
	if Engine.has_singleton(STATE_AUTOLOAD_NAME):
		remove_autoload_singleton(STATE_AUTOLOAD_NAME)
#endregion

#region Callables
func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> AfterGUIInput:
	# Leave selection and camera navigation to Godot when the tool is inactive.
	if not is_instance_valid(self.active_world) or not self.build_town_button.button_pressed:
		return AFTER_GUI_INPUT_PASS
	var terrain: Terrain3D = self.active_world.terrain
	if not is_instance_valid(terrain):
		return AFTER_GUI_INPUT_PASS
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return AFTER_GUI_INPUT_PASS
	var mouse_event: InputEventMouse = event as InputEventMouse
	terrain.set_camera(camera)
	# Terrain3D's intersection can be one frame behind, so update on motion too.
	var point: Vector3 = terrain.get_intersection(camera.project_ray_origin(mouse_event.position), camera.project_ray_normal(mouse_event.position), true)
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		# Modifier clicks are reserved for editor selection and navigation.
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and not (button.alt_pressed or button.ctrl_pressed or button.shift_pressed or button.meta_pressed):
			# Terrain3D uses an extreme Z value or NaN when the ray misses.
			if point.is_finite() and point.z < 3.4e38:
				self.editor_signals.terrain_clicked.emit(point)
				# Prevent this placement click from also selecting an editor object.
				return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _on_scene_changed(root: Node) -> void:
	# Clear the old subscription and placement mode before tracking the new map.
	self._disconnect_world()
	self.build_town_button.set_pressed_no_signal(false)
	self.active_world = root as WorldMapScene
	self.build_town_button.disabled = self.active_world == null
	if self.active_world:
		self.editor_signals.terrain_clicked.connect(self._on_terrain_clicked)

func _disconnect_world() -> void:
	if self.editor_signals.terrain_clicked.is_connected(self._on_terrain_clicked):
		self.editor_signals.terrain_clicked.disconnect(self._on_terrain_clicked)
	self.active_world = null

func _on_terrain_clicked(position: Vector3) -> void:
	# Town placement will be implemented by the map-editing tool.
	print("HinterlandTycoon terrain click: ", position)

func _on_root_scene_node_added():
	Loggie.info("Node added")
#endregion
