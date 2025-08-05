extends Timer

@export_storage var station_manager: StationsHolder

func _enter_tree() -> void:
	self.timeout.connect(Callable(self, "_on_timer_timeout"))
	
func _ready() -> void:
	if ! self.get_parent() || ! self.get_parent() is StationsHolder:
		Loggie.error("Cannot connect Stations timer: isnt under StationsHolder manager parent")
	self.station_manager = self.get_parent()

func _on_timer_timeout():
	self.station_manager._on_station_timer_tick()
