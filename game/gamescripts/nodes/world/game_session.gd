@icon("res://assets/icons/nodes_3d/icon_game_session.svg")
class_name GameSession extends Node3D

signal scene_root_ready()

@onready var player: PlayerAvatar = get_node_or_null("PlayerAvatar")
@onready var world_interaction: WorldInteraction = get_node_or_null("Input/WorldInteraction")
@onready var world_services: WorldServicesCoordinator = $WorldServices

func _ready() -> void:
	var menu := get_node_or_null("GameWindow/OuterRadialMenu") as RadialActionMenu
	var actions := get_node_or_null("Input/ActionHandler") as ActionHandler
	if menu != null and actions != null:
		menu.action_requested.connect(actions._on_action_triggered)
	if player != null:
		player.control.camera_changed.connect(_on_player_camera_changed)
		SignalBus.map_spawned.connect(_on_map_spawned)
	if GameTypes.is_initialized:
		self._on_types_initialized()
		return
	SignalBus.all_types_initialized.connect(self._on_types_initialized, CONNECT_ONE_SHOT)
	if GameTypes.is_initializing:
		return
	var error: Error = GameTypes.ensure_initialized()
	if error != OK:
		SignalBus.all_types_initialized.disconnect(self._on_types_initialized)
		push_error("Game session cannot start: type initialization failed (%s)" % error_string(error))

func _on_map_spawned(world: WorldMapScene) -> void:
	if world != world_services.map_spawner.terrain_container:
		return
	var map := GlobalState.loaded_map
	if map != null and map.start_pos_xz != Vector2.ZERO and is_instance_valid(world.terrain):
		var start := Vector3(map.start_pos_xz.x, 0, map.start_pos_xz.y)
		var position := world.get_pos_at_height(start)
		if position.is_finite():
			player.place_at(position + Vector3.UP)
	_on_player_camera_changed(player.control.active_camera())


func _on_player_camera_changed(camera: Camera3D) -> void:
	if not is_instance_valid(world_services) or not is_instance_valid(world_services.map_spawner):
		return
	var world := world_services.map_spawner.terrain_container
	if is_instance_valid(world) and is_instance_valid(world.terrain):
		world.terrain.set_camera(camera)


func _on_types_initialized() -> void:
	if self.world_services == null:
		push_error("Game session requires a WorldServices coordinator")
		return
	if self.world_services.is_initialized:
		self._on_services_initialized()
		return
	self.world_services.services_initialized.connect(self._on_services_initialized, CONNECT_ONE_SHOT)
	var error: Error = self.world_services.initialize()
	if error != OK:
		self.world_services.services_initialized.disconnect(self._on_services_initialized)
		push_error("Game session cannot start: service initialization failed (%s)" % error_string(error))

func _on_services_initialized() -> void:
	if world_interaction != null:
		world_interaction.terrain_clicked.connect(world_services.rail_builder._on_terrain_click)
	self.scene_root_ready.emit()
	SignalBus.scene_root_ready.emit()
