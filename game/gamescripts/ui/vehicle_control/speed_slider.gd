class_name SpeedSlider extends CenterContainer

@export var current_train: Train3D

func _enter_tree() -> void:
	SignalBus.player_entered_train.connect(Callable(self, "_on_player_entered_train"))
	SignalBus.player_exited_train.connect(Callable(self, "_on_player_exited_train"))

func _ready() -> void:
	$VSlider.value_changed.connect(Callable(self, "_on_speed_slider_change"))
	
#region Callbacks
func _on_speed_slider_change(scaled_speed: float):
	if self.current_train:
		var current_speed: VehicleSpeed = self.current_train.motor.speed
		current_speed.target = (scaled_speed /100.0)
		Loggie.info("Set target speed to %.1f" % scaled_speed)
	else:
		Loggie.warn("Cannot change vehicle speed: no player train registered")

func _on_player_entered_train(train: Train3D):
	self.current_train = train

func _on_player_exited_train():
	self.current_train = null
#endregion
