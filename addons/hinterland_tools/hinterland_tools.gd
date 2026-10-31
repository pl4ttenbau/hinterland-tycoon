@tool
extends EditorPlugin

const TOOLS_PANEL_SCENE = preload("res://addons/hinterland_tools/editor_tools_panel.tscn")
const STATE_AUTOLOAD_NAME = "EditorState"
const EDITOR_SIGNALS_SCRIPT = preload("res://addons/hinterland_tools/editor_signals.gd")

var editor_signals: Node
var map_panel: VBoxContainer
var tool_status: Label
var build_town_button: Button
var active_world: WorldMapScene
var road_button: Button
var rail_button: Button
var json_store = preload("res://addons/hinterland_tools/infr_json_store.gd").new()
var file_buttons: Array[Button] = []
var file_status: Label

var drawing = preload("res://addons/hinterland_tools/infr_drawing_tool.gd").new()

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
	self.map_panel = TOOLS_PANEL_SCENE.instantiate()
	# Unique scene names keep the plugin independent of the panel's container layout.
	self.build_town_button = self.map_panel.get_node("%BuildTown")
	self.road_button = self.map_panel.get_node("%CreateRoad")
	self.rail_button = self.map_panel.get_node("%CreateRail")
	self.tool_status = self.map_panel.get_node("%ToolStatus")
	self.file_status = self.map_panel.get_node("%FileStatus")
	self.map_panel.get_node("%FreeTool").pressed.connect(self._on_free_tool_pressed)
	for domain: Enums.InfrDomain in [Enums.InfrDomain.ROAD, Enums.InfrDomain.RAIL]:
		var suffix: String = "Roads" if domain == Enums.InfrDomain.ROAD else "Rails"
		for operation: String in ["Save", "Load"]:
			var button: Button = self.map_panel.get_node("%" + operation + suffix)
			button.pressed.connect(self._on_json_action.bind(operation == "Save", domain))
			self.file_buttons.append(button)
	self.road_button.toggled.connect(self._on_draw_toggled.bind(Enums.InfrDomain.ROAD))
	self.rail_button.toggled.connect(self._on_draw_toggled.bind(Enums.InfrDomain.RAIL))
	# Defer until ButtonGroup has finished unpressing the previous tool.
	for button: Button in [self.build_town_button, self.road_button, self.rail_button]:
		button.toggled.connect(self._update_tool_status.unbind(1), CONNECT_DEFERRED)
	self.editor_signals.terrain_clicked.connect(self.drawing.add_point)
	self.add_control_to_bottom_panel(self.map_panel, "HinterlandTycoon")
	self.scene_changed.connect(self._on_scene_changed)
	self.get_undo_redo().version_changed.connect(self._on_history_version_changed, CONNECT_DEFERRED)
	# Receive viewport input even when no node handled by this plugin is selected.
	self.set_input_event_forwarding_always_enabled()
	# The plugin may be enabled after a map is already open.
	self._on_scene_changed(EditorInterface.get_edited_scene_root())
	self.enable_editor_state()

func _exit_tree() -> void:
	print("Deactivating HinterlandTycoon plugin")
	self._disconnect_world()
	self.scene_changed.disconnect(self._on_scene_changed)
	self.get_undo_redo().version_changed.disconnect(self._on_history_version_changed)
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
	if not is_instance_valid(self.active_world) or not (self.build_town_button.button_pressed or self.road_button.button_pressed or self.rail_button.button_pressed):
		return AFTER_GUI_INPUT_PASS
	var drawing_active: bool = self.road_button.button_pressed or self.rail_button.button_pressed
	if drawing_active and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			self.drawing.finish(self.get_undo_redo())
			return AFTER_GUI_INPUT_STOP
		if event.keycode == KEY_BACKSPACE:
			self.drawing.remove_last()
			return AFTER_GUI_INPUT_STOP
		if event.keycode == KEY_ESCAPE:
			self.drawing.begin(self.active_world, self.drawing.domain)
			return AFTER_GUI_INPUT_STOP
	var terrain: Terrain3D = self.active_world.terrain
	if not is_instance_valid(terrain):
		return AFTER_GUI_INPUT_PASS
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return AFTER_GUI_INPUT_PASS
	var mouse_event: InputEventMouse = event as InputEventMouse
	if mouse_event.alt_pressed or mouse_event.ctrl_pressed or mouse_event.shift_pressed or mouse_event.meta_pressed or (event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)):
		if drawing_active:
			self.drawing.hide_pointer()
		return AFTER_GUI_INPUT_PASS
	terrain.set_camera(camera)
	# Terrain3D's intersection can be one frame behind, so update on motion too.
	var point: Vector3 = terrain.get_intersection(camera.project_ray_origin(mouse_event.position), camera.project_ray_normal(mouse_event.position), true)
	var terrain_valid: bool = point.is_finite() and point.z < 3.4e38
	if drawing_active:
		self.drawing.update_pointer(camera, mouse_event.position, point, terrain_valid)
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		# Modifier clicks are reserved for editor selection and navigation.
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and not (button.alt_pressed or button.ctrl_pressed or button.shift_pressed or button.meta_pressed):
			# Terrain3D uses an extreme Z value or NaN when the ray misses.
			if terrain_valid or (drawing_active and self.drawing.placement_valid):
				self.editor_signals.terrain_clicked.emit(point if terrain_valid else self.drawing.placement)
				# Prevent this placement click from also selecting an editor object.
				return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _on_scene_changed(root: Node) -> void:
	# Clear the old subscription and placement mode before tracking the new map.
	self._disconnect_world()
	self.build_town_button.set_pressed_no_signal(false)
	self.road_button.set_pressed_no_signal(false)
	self.rail_button.set_pressed_no_signal(false)
	self.active_world = root as WorldMapScene
	self.build_town_button.disabled = self.active_world == null
	self.road_button.disabled = self.active_world == null
	self.rail_button.disabled = self.active_world == null
	self._update_tool_status()
	self.json_store.managed_ids.clear()
	self.file_status.text = "Save JSON keeps a backup and clears the saved cache. Load JSON restores it."
	for button: Button in self.file_buttons:
		button.disabled = self.active_world == null
	if self.active_world:
		self.editor_signals.terrain_clicked.connect(self._on_terrain_clicked)

func _disconnect_world() -> void:
	self.drawing.clear()
	if self.editor_signals.terrain_clicked.is_connected(self._on_terrain_clicked):
		self.editor_signals.terrain_clicked.disconnect(self._on_terrain_clicked)
	self.active_world = null

func _on_terrain_clicked(position: Vector3) -> void:
	if not self.build_town_button.button_pressed:
		return
	# Town placement will be implemented by the map-editing tool.
	print("HinterlandTycoon terrain click: ", position)

func _on_root_scene_node_added():
	Loggie.info("Node added")
#endregion

func _on_draw_toggled(enabled: bool, domain: Enums.InfrDomain) -> void:
	if enabled and is_instance_valid(self.active_world):
		self.drawing.begin(self.active_world, domain)
	elif self.drawing.domain == domain:
		self.drawing.clear()

func _on_free_tool_pressed() -> void:
	for button: Button in [self.build_town_button, self.road_button, self.rail_button]:
		button.set_pressed_no_signal(false)
	self.drawing.clear()
	self._update_tool_status()

func _update_tool_status() -> void:
	if not is_instance_valid(self.active_world):
		self.tool_status.text = "No tool selected · Open a world map to use the editor tools."
	elif self.road_button.button_pressed or self.rail_button.button_pressed:
		var selected: String = "Create Road" if self.road_button.button_pressed else "Create Rail"
		self.tool_status.text = selected + " · Click terrain to add points; green sphere snaps to an endpoint · Enter: finish · Backspace: remove last point · Esc: cancel draft"
	elif self.build_town_button.button_pressed:
		self.tool_status.text = "Build Town · Click terrain to pick a position (placement is not implemented yet) · Click Build Town again to leave the tool."
	else:
		self.tool_status.text = "No tool selected · Select Create Road or Create Rail to start drawing."

func _on_json_action(save: bool, domain: Enums.InfrDomain) -> void:
	if not is_instance_valid(self.active_world):
		return
	if not self.drawing.points.is_empty():
		self.file_status.text = "Finish the current draft with Enter or cancel it with Esc before saving/loading."
		return
	var result: Dictionary = self.json_store.save_world(self.active_world, domain) if save else self.json_store.load_world(self.active_world, domain, self.get_undo_redo())
	if not result.ok:
		self.file_status.text = result.error
		push_warning(result.error)
		return
	var kind: String = "roads" if domain == Enums.InfrDomain.ROAD else "rails"
	self.file_status.text = "%s %d %s." % ["Saved" if save else "Loaded", result.count, kind]
	if save:
		self.json_store.flush_saved(self.active_world, domain, self.get_undo_redo())
		self.file_status.text += " Visible cache cleared; Load JSON restores it."
		self.file_status.text += " Backup: " + result.backup if not result.backup.is_empty() else " New JSON file created."
		EditorInterface.get_resource_filesystem().scan()
	if is_instance_valid(self.drawing.world):
		self.drawing.refresh_endpoints()
		self.drawing.hide_pointer()

func _on_history_version_changed() -> void:
	# Loading replaces whole subtrees. Undo can bring back older endpoint nodes,
	# so rebuild snap targets instead of retaining references to detached lines.
	if is_instance_valid(self.drawing.world):
		self.drawing.refresh_endpoints()
		self.drawing.hide_pointer()
