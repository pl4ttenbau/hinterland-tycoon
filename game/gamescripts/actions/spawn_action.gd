class_name SpawnAction extends Node

const VEHICLE_SELECT_DIAG_SCENE = "res://scenes/ui/dialogs/select_vehicle_dialog.tscn"

func on_trigger():
	var diag_scene: PackedScene = load(VEHICLE_SELECT_DIAG_SCENE)
	var instance: SelectVehicleDialog = diag_scene.instantiate()
	# connect to signal
	instance.vehicle_spawn_triggered.connect(Callable(self, "_on_vehicle_spawn_pressed"))
	# show dialog
	$/root.add_child(instance)
		
func spawn_vehicle(veh_type_key: String):
	var closest_depot := self.get_closest_depot()
	if closest_depot:
		var depot_obj := closest_depot.depot
		var depot_node_index := depot_obj.get_depot_rail_node().index
		var veh_dir = self.get_veh_dir_from_depot_pos(depot_obj.track_pos)
		Loggie.info("Spawn new vehicle in direction: %s" % veh_dir)
		var veh := Managers.vehicles.spawn_vehicle(veh_type_key, depot_obj.track_num, depot_node_index, veh_dir)
		# start
		veh.motor.start()
		
func get_veh_dir_from_depot_pos(depot_pos: String) -> VehicleMotor.Direction:
	if depot_pos == "START": return VehicleMotor.Direction.TRACK_NODES_INCREASE
	return VehicleMotor.Direction.TRACK_NODES_DECREASE

func get_closest_depot() -> OuterDepot:
	var closest_dist: float = 9999.0
	var closest_depot: OuterDepot = null
	for outer_depot: OuterDepot in Managers.depots.containers:
		var player_pos := GlobalState.player.global_position
		var dist = player_pos.distance_to(outer_depot.position)
		# nähestes gefundenes Depot: Update gecachten Wert
		if dist < closest_dist:
			closest_depot = outer_depot
			closest_dist = dist
	Loggie.info("Closest depot: %s at %v" % [closest_depot.name, closest_depot.position])
	return closest_depot
	
	
#region Callbacks
func _on_vehicle_spawn_pressed(veh_type_str: String) -> void:
	Loggie.info("Vehicle spawning btn pressed: %s" % veh_type_str)
	self.spawn_vehicle(veh_type_str)
#endregion
