class_name StationCatchmentArea extends Area3D

signal area_connected(_station_area: StationCatchmentArea)

signal train_entered(train3d: Train3D)
signal train_exited(train3d: Train3D)

signal player_entered()
signal player_exited()

@export var parent_station: RailStationData

@export var trains_inside: Array[Train3D] = []
@export var vehicles_inside: Array[Vehicle3D] = []
@export var player_inside = false

#region Initialization
func _enter_tree() -> void:
	self.body_entered.connect(Callable(self, "_on_body_entered"))
	self.body_exited.connect(Callable(self, "_on_body_exited"))
	self.area_connected.emit(self)

func _ready() -> void:
	var node_station_3d: RailNodeStation3D = self.get_parent_node_3d() as RailNodeStation3D
	self.parent_station = node_station_3d.station_obj
#endregion

#region Helper-Methods
func trigger_train_entered(train3d: Train3D):
	Loggie.info("Train entering station area")
	self.trains_inside.append(train3d)
	# set station in train
	train3d.current_station = self
	# call local & global signal
	self.train_entered.emit(train3d)
	SignalBus.train_entered_station.emit(self.parent_station, train3d)

func trigger_train_exited(train3d: Train3D):
	Loggie.info("Train leaving station area")
	self.trains_inside.erase(train3d)
	# unset station in train
	train3d.current_station = null
	# call local & global signal
	self.train_exited.emit(train3d)
	SignalBus.train_exited_station.emit(self.parent_station, train3d)

func veh3d_is_locomotive(veh3d: Vehicle3D) -> bool:
	return veh3d.vehicle_obj.veh_type.is_locomotive()
#endregion

#region Callbacks
func _on_body_entered(body: Node3D):
	if body is CharacterBody3D:
		self.player_inside = true
		self.player_entered.emit()
		SignalBus.player_entered_station.emit(self.parent_station)
	elif body is VehicleCollider:
		self.vehicles_inside.append(body.vehicle3d)
		if self.veh3d_is_locomotive(body.vehicle3d):
			self.trigger_train_entered(body.vehicle3d.train3d)

func _on_body_exited(body: Node3D):
	if body is CharacterBody3D:
		self.player_inside = false
		self.player_exited.emit()
		SignalBus.player_exited_station.emit(self.parent_station)
	elif body is VehicleCollider:
		self.vehicles_inside.erase(body.vehicle3d)
		if self.veh3d_is_locomotive(body.vehicle3d):
			self.trigger_train_exited(body.vehicle3d.train3d)
#endregion
