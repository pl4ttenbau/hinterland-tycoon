@tool
## Owns the editor toolbar, viewport input, scene changes and JSON actions.
class_name HinterlandEditorPlugin extends EditorPlugin

const TOOLS_PANEL_SCENE = preload("res://addons/hinterland_tools/editor_tools_panel.tscn")
const STATE_AUTOLOAD_NAME = "EditorState"

var editor_signals: HinterlandEditorSignals
var map_panel: VBoxContainer
var tool_buttons: Dictionary[Enums.EnumEditorTool, Button] = {}
var tool_status: Label
var active_world: WorldMapScene
var json_store = InfrJsonStore.new()
var object_selection := ObjectSelectedTool.new()
var file_status: Label
var residence_road_preview: EditorResidenceRoadPreview
var line_node_markers: InfrLineNodeMarkers

var drawing = InfrDrawingTool.new()

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
	self.editor_signals = HinterlandEditorSignals.new()
	self.editor_signals.name = "EditorSignals"
	self.add_child(self.editor_signals)
	self.residence_road_preview = EditorResidenceRoadPreview.new()
	self.add_child(self.residence_road_preview)
	self.line_node_markers = InfrLineNodeMarkers.new()
	self.add_child(self.line_node_markers)
	self.map_panel = TOOLS_PANEL_SCENE.instantiate()
	# Unique scene names keep the plugin independent of the panel's container layout.
	# add tool buttons
	self.add_tool_buttons()
	# add bottom panel
	self.editor_signals.terrain_clicked.connect(self.drawing.add_point)
	self.add_control_to_bottom_panel(self.map_panel, "HinterlandTycoon")
	_connect_editor_events()
	# The plugin may be enabled after a map is already open.
	self._on_scene_changed(EditorInterface.get_edited_scene_root())
	self.enable_editor_state()

func _connect_editor_events() -> void:
	# wire scene change and history
	self.scene_changed.connect(self._on_scene_changed)
	self.get_undo_redo().version_changed.connect(self._on_history_version_changed, CONNECT_DEFERRED)
	# Receive viewport input even when no node handled by this plugin is selected.
	self.set_input_event_forwarding_always_enabled()


## Build a toolbar lookup and give this panel one shared, independent group.
## Nested button scenes otherwise duplicate local-to-scene ButtonGroups per button.
static func create_tool_buttons(panel: Control) -> Dictionary[Enums.EnumEditorTool, Button]:
	var buttons: Dictionary[Enums.EnumEditorTool, Button] = {
		Enums.EnumEditorTool.NONE: panel.get_node("%FreeTool"),
		Enums.EnumEditorTool.BUILD_TOWN: panel.get_node("%BuildTown"),
		Enums.EnumEditorTool.CREATE_ROAD: panel.get_node("%CreateRoad"),
		Enums.EnumEditorTool.CREATE_RAIL: panel.get_node("%CreateRail"),
		Enums.EnumEditorTool.SELECT_OBJECT: panel.get_node("%SelectObject"),
	}
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for tool: Enums.EnumEditorTool in buttons:
		if tool != Enums.EnumEditorTool.NONE:
			buttons[tool].button_group = group
	return buttons

func add_tool_buttons() -> void:
	tool_buttons = create_tool_buttons(map_panel)
	tool_status = map_panel.get_node("%ToolStatus")
	file_status = map_panel.get_node("%FileStatus")
	tool_buttons[Enums.EnumEditorTool.NONE].pressed.connect(_on_free_tool_pressed)
	editor_signals.infrastructure_save_requested.connect(_on_cache_save_requested)
	tool_buttons[Enums.EnumEditorTool.CREATE_ROAD].toggled.connect(_on_draw_toggled.bind(Enums.InfrDomain.ROAD))
	tool_buttons[Enums.EnumEditorTool.CREATE_RAIL].toggled.connect(_on_draw_toggled.bind(Enums.InfrDomain.RAIL))
	for tool: Enums.EnumEditorTool in tool_buttons:
		if tool != Enums.EnumEditorTool.NONE:
			# Defer until the shared ButtonGroup has released the previous tool.
			tool_buttons[tool].toggled.connect(_update_tool_status.unbind(1), CONNECT_DEFERRED)

func is_tool_active(tool: Enums.EnumEditorTool) -> bool:
	var button: Button = tool_buttons.get(tool)
	return is_instance_valid(button) and button.button_pressed

func _exit_tree() -> void:
	print("Deactivating HinterlandTycoon plugin")
	self._disconnect_world()
	if is_instance_valid(self.residence_road_preview):
		self.residence_road_preview.queue_free()
	if is_instance_valid(self.line_node_markers):
		self.line_node_markers.clear()
		self.line_node_markers.queue_free()
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
func _handles(object: Object) -> bool:
	return object is EditorInfrLine3D

func _edit(object: Object) -> void:
	if is_instance_valid(self.line_node_markers):
		self.line_node_markers.show_line(object as EditorInfrLine3D)

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> AfterGUIInput:
	if is_instance_valid(self.line_node_markers):
		self.line_node_markers.set_process(true)
		self.line_node_markers.update_view(camera)
	# Leave selection and camera navigation to Godot when the tool is inactive.
	if not is_instance_valid(self.active_world) or not (is_tool_active(Enums.EnumEditorTool.BUILD_TOWN) or is_tool_active(Enums.EnumEditorTool.CREATE_ROAD) or is_tool_active(Enums.EnumEditorTool.CREATE_RAIL) or self._selection_active()):
		return AFTER_GUI_INPUT_PASS
	if self._selection_active():
		return self._forward_selection_input(camera, event)
	var drawing_active: bool = is_tool_active(Enums.EnumEditorTool.CREATE_ROAD) or is_tool_active(Enums.EnumEditorTool.CREATE_RAIL)
	if drawing_active and _handle_drawing_key(event):
		return AFTER_GUI_INPUT_STOP
	return _forward_terrain_input(camera, event, drawing_active)

func _handle_drawing_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			self.drawing.finish(self.get_undo_redo())
			return true
		if event.keycode == KEY_BACKSPACE:
			self.drawing.remove_last()
			return true
		if event.keycode == KEY_ESCAPE:
			self.drawing.begin(self.active_world, self.drawing.domain)
			return true
	return false

func _forward_terrain_input(camera: Camera3D, event: InputEvent, drawing_active: bool) -> AfterGUIInput:
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
		return _accept_terrain_click(event, point, terrain_valid, drawing_active)
	return AFTER_GUI_INPUT_PASS

func _accept_terrain_click(event: InputEventMouseButton, point: Vector3, terrain_valid: bool, drawing_active: bool) -> AfterGUIInput:
	# Modifier clicks are reserved for editor selection and navigation.
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not (event.alt_pressed or event.ctrl_pressed or event.shift_pressed or event.meta_pressed):
		# Terrain3D uses an extreme Z value or NaN when the ray misses.
		if terrain_valid or (drawing_active and self.drawing.placement_valid):
			self.editor_signals.terrain_clicked.emit(point if terrain_valid else self.drawing.placement)
			# Prevent this placement click from also selecting an editor object.
			return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _on_scene_changed(root: Node) -> void:
	# Clear the old subscription and placement mode before tracking the new map.
	self._disconnect_world()
	for tool: Enums.EnumEditorTool in tool_buttons:
		if tool != Enums.EnumEditorTool.NONE:
			tool_buttons[tool].set_pressed_no_signal(false)
	self.active_world = root as WorldMapScene
	if root is WorldEditorObjects:
		root.json_history = self.get_undo_redo()

	for tool: Enums.EnumEditorTool in tool_buttons:
		if tool != Enums.EnumEditorTool.NONE:
			tool_buttons[tool].disabled = self.active_world == null
	self._update_tool_status()
	self.file_status.text = "Save JSON from the EditorCache Inspector. Load JSON from the EditorObjects Inspector."
	if self.active_world:
		var connections: Node = RoadEndpointConnection.ensure(self.active_world)
		connections.edit_history = self.get_undo_redo()
		self.editor_signals.terrain_clicked.connect(self._on_terrain_clicked)

func _disconnect_world() -> void:
	self.drawing.clear()
	if is_instance_valid(self.line_node_markers):
		self.line_node_markers.clear()
	if self.editor_signals.terrain_clicked.is_connected(self._on_terrain_clicked):
		self.editor_signals.terrain_clicked.disconnect(self._on_terrain_clicked)
	self.active_world = null

func _on_terrain_clicked(position: Vector3) -> void:
	if not is_tool_active(Enums.EnumEditorTool.BUILD_TOWN):
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
	for tool: Enums.EnumEditorTool in tool_buttons:
		if tool != Enums.EnumEditorTool.NONE:
			tool_buttons[tool].set_pressed_no_signal(false)
	self.drawing.clear()
	self._update_tool_status()

func _update_tool_status() -> void:
	if not is_instance_valid(self.active_world):
		self.tool_status.text = "No tool selected · Open a world map to use the editor tools."
	elif self._selection_active():
		self.tool_status.text = "Select Object · Click a visible road/rail to inspect its ID and properties · Esc or Free Tool: leave selection mode"
	elif is_tool_active(Enums.EnumEditorTool.CREATE_ROAD) or is_tool_active(Enums.EnumEditorTool.CREATE_RAIL):
		var selected: String = "Create Road" if is_tool_active(Enums.EnumEditorTool.CREATE_ROAD) else "Create Rail"
		self.tool_status.text = selected + " · Click terrain to add points; green sphere snaps to an endpoint · Enter: finish · Backspace: remove last point · Esc: cancel draft"
	elif is_tool_active(Enums.EnumEditorTool.BUILD_TOWN):
		self.tool_status.text = "Build Town · Click terrain to pick a position (placement is not implemented yet) · Click Build Town again to leave the tool."
	else:
		self.tool_status.text = "No tool selected · Select Create Road or Create Rail to start drawing."

# Existing editor instances can retain signal connections during script hot reload.
# Keep old buttons safe until the panel is recreated on the next plugin restart.
func _on_json_action(save: bool, domain: Enums.InfrDomain) -> void:
	if save:
		_on_json_save(domain)
	else:
		self.file_status.text = "Load JSON moved to the standalone EditorObjects Inspector. Reopen the plugin to update this panel."

func _on_cache_save_requested(cache: Node3D, domain: int) -> void:
	if not is_instance_valid(cache) or not is_instance_valid(self.active_world) or cache.get_parent() != self.active_world or cache != self.active_world.get_node_or_null("EditorCache"):
		push_warning("Open the cache's world map before saving its JSON.")
		return
	if domain not in [Enums.InfrDomain.ROAD, Enums.InfrDomain.RAIL]:
		return
	_on_json_save(domain)

func _selection_active() -> bool:
	# A live pre-update panel may not have the new button until plugin restart.
	return is_tool_active(Enums.EnumEditorTool.SELECT_OBJECT)

func _forward_selection_input(camera: Camera3D, event: InputEvent) -> AfterGUIInput:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_free_tool_pressed()
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:
		# Terrain3D's GPU intersection can lag by one frame. Prime it on pointer
		# movement so click occlusion uses the current pointer, just as drawing does.
		if not (event.alt_pressed or event.ctrl_pressed or event.shift_pressed or event.meta_pressed or event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)):
			_selection_depth(camera, event.position)
		return AFTER_GUI_INPUT_PASS
	if not event is InputEventMouseButton:
		return AFTER_GUI_INPUT_PASS
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or event.alt_pressed or event.ctrl_pressed or event.shift_pressed or event.meta_pressed:
		return AFTER_GUI_INPUT_PASS
	var max_depth: float = _selection_depth(camera, event.position)
	var hit: EditorPickHit = self.object_selection.pick(self.active_world, camera, event.position, max_depth)
	if hit == null:
		self.tool_status.text = "Select Object · No selectable road/rail at this position"
		return AFTER_GUI_INPUT_PASS
	_inspect_selection_hit(hit)
	return AFTER_GUI_INPUT_STOP

func _inspect_selection_hit(hit: EditorPickHit) -> void:
	var target: Node = hit.target
	# Inspect the actual line even when native selection would stop at the
	# enclosing subscene. This does not enable Editable Children or move it.
	EditorInterface.get_selection().clear()
	# Native scene selection can redirect a locked child back to its instance
	# root. Use it only for map-owned nodes; inspect source children directly.
	if target.owner == self.active_world:
		EditorInterface.get_selection().add_node(target)
	EditorInterface.inspect_object(target, "", true)
	self.tool_status.text = "Select Object · " + (hit.label if not hit.label.is_empty() else str(target.name))


func _selection_depth(camera: Camera3D, mouse: Vector2) -> float:
	if is_instance_valid(self.active_world.terrain):
		var terrain: Terrain3D = self.active_world.terrain
		terrain.set_camera(camera)
		var origin: Vector3 = camera.project_ray_origin(mouse)
		var direction: Vector3 = camera.project_ray_normal(mouse)
		var point: Vector3 = terrain.get_intersection(origin, direction, true)
		if point.is_finite() and point.z < 3.4e38:
			return (point - origin).dot(direction)
	return INF

func _on_json_save(domain: Enums.InfrDomain) -> void:
	if not is_instance_valid(self.active_world):
		return
	if not self.drawing.points.is_empty():
		self.file_status.text = "Finish the current draft with Enter or cancel it with Esc before saving."
		return
	var result: EditorActionResult = self.json_store.save_world(self.active_world, domain)
	if not result.ok:
		self.file_status.text = result.error
		push_warning(result.error)
		return
	var kind: String = "roads" if domain == Enums.InfrDomain.ROAD else "rails"
	self.json_store.flush_saved(self.active_world, domain, self.get_undo_redo())
	self.file_status.text = "Saved %d %s. Cache cleared; load JSON in the EditorObjects Inspector." % [result.count, kind]
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
