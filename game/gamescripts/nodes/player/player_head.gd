@icon("res://assets/icons/godot_default/icon_character_3d.svg")
class_name PlayerHead3D extends InventoryEntity3D

@export var player_data: PlayerData:
	set(value): self.entity = value
	get(): return self.entity as PlayerData

@onready var cam: Camera3D = $Camera3D
@onready var collider: CollisionShape3D = %Player/PlayerCollisionShape
@onready var player_parent: BasicFpsPlayer = $".."

@export var in_station: RailStation3D
@export var in_train: Train3D

const SPAWN_OFFSET = Vector3(0, 1, 0)

#region Initialization
func _enter_tree() -> void:
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))
	# player entwering & leaving stations
	SignalBus.player_entered_station.connect(Callable(self, "_on_station_entered"))
	SignalBus.player_exited_station.connect(Callable(self, "_on_station_exited"))
	# player entering & leaving train
	SignalBus.player_entered_train.connect(Callable(self, "_on_train_entered"))
	SignalBus.player_exited_train.connect(Callable(self, "_on_train_exited"))

func _ready() -> void:
	self.player_data = PlayerData.new()
	GlobalState.player = self
	GlobalState.active_cam = self.cam

func place_to_map_start():
	if GlobalState.loaded_map && GlobalState.loaded_map.start_pos_xz:
		var spawn_pos = WorldUtils.pos_on_map(GlobalState.loaded_map.start_pos_xz)
		self.get_parent_node_3d().position = spawn_pos + SPAWN_OFFSET
#endregion

#region Getters
static func get_cam_pos() -> Vector3:
	if GlobalState.active_cam != null:
		return GlobalState.active_cam.global_position
	return GlobalState.player.global_position

func get_pos() -> Vector3:
	return self.player_parent.position
#endregion

#region Callbacks
func _on_map_spawned(_terrain: WorldMapScene):
	self.place_to_map_start()

func _on_station_entered(station3d: RailStation3D):
	Loggie.info("Player entering station %s" % station3d.station.station_name)
	self.in_station = station3d

func _on_station_exited(station3d: RailStation3D):
	Loggie.info("Player leaving station %s" % station3d.station.station_name)
	self.in_station = null

func _on_train_entered(train3d: Train3D):
	self.in_train = train3d

func _on_train_exited():
	self.in_train = null
#endregion
