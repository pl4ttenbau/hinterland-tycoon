@icon("res://assets/icons/nodes_3d/icon_game_session.svg")
class_name GameSession extends Node3D

signal scene_root_ready()

@onready var world_services: WorldServicesCoordinator = $WorldServices

func _ready() -> void:
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
	self.scene_root_ready.emit()
	SignalBus.scene_root_ready.emit()
