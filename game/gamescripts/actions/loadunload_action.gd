class_name LoadUnloadAction extends BaseAction

@export var player_train: Train3D = null

func _enter_tree() -> void:
	SignalBus.train_entered.connect(Callable(self, "_on_train_entered"))
	SignalBus.train_exited.connect(Callable(self, "_on_train_exited"))

func on_trigger():
	super.on_trigger()
	if !self.player_train:
		Loggie.warn("Cant Load/Unload: Player isnt in a train")
		return
	if self.player_train:
		var loco_pos: Vector3 = self.player_train.locomotive.position
		var train_station: RailStationData = Managers.stations.get_station_around_pos(loco_pos)
		if train_station:
			Loggie.info("Train is at station \"%s\"!" % train_station.station_name)

#region Callables
func _on_train_entered(train3d: Train3D):
	self.player_train = train3d

func _on_train_exited():
	self.player_train = null
#endregion
