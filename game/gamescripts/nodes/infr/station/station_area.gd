class_name StationArea extends Area3D

signal train_entered(train3d: Train3D)
signal train_exited(train3d: Train3D)

signal player_entered()
signal player_exited()

@export var trains_inside: Array[Train3D] = []
@export var vehicles_inside: Array[Vehicle3D] = []
@export var player_inside = false

#region Initialization
func _enter_tree() -> void:
	self.body_entered.connect(Callable(self, "_on_body_entered"))
	self.body_exited.connect(Callable(self, "_on_body_exited"))
#endregion

func has_no_more_train_vehicles_inside(train3d: Train3D) -> bool:
	for vehicle_in_station: Vehicle3D in self.vehicles_inside:
		if vehicle_in_station.train3d == train3d:
			return false
	return true

func veh3d_is_locomotive(veh3d: Vehicle3D) -> bool:
	return veh3d.vehicle_obj.veh_type.is_locomotive()

#region Callbacks
func _on_body_entered(body: Node3D):
	Loggie.info("Body entered: %s" % body.name)
	if body is CharacterBody3D:
		self.player_inside = true
		self.player_entered.emit()
	elif body is VehicleCollider:
		Loggie.info("Vehicle entering station area")
		self.vehicles_inside.append(body.vehicle3d)
		if self.veh3d_is_locomotive(body.vehicle3d):
			Loggie.info("Train entering station area")
			self.trains_inside.append(body.vehicle3d.train3d)
			self.train_entered.emit(body.vehicle3d.train3d)

func _on_body_exited(body: Node3D):
	if body is CharacterBody3D:
		self.player_inside = false
		self.player_exited.emit()
	elif body is VehicleCollider:
		Loggie.info("Vehicle leaving station area")
		self.vehicles_inside.erase(body.vehicle3d)
		if self.veh3d_is_locomotive(body.vehicle3d):
			Loggie.info("Train leaving station area")
			self.trains_inside.erase(body.vehicle3d.train3d)
			self.train_exited.emit(body.vehicle3d.train3d)
#endregion
