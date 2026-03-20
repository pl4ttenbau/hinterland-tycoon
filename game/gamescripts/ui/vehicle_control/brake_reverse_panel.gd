@icon("res://assets/icons/icon_speedometer_ui.png")
class_name BrakeReversePanel extends CenterContainer

@export var curr_train: Train3D

@export var brake: bool = false
@export var reverse: bool = false

#region Initialization
func _ready() -> void:
	# connect to vehicle
	SignalBus.train_entered.connect(Callable(self, "_on_train_entered"))
	SignalBus.train_exited.connect(Callable(self, "_on_train_exited"))
	# connect Brake & Reverse buttons
	%BrakeButton.toggled.connect(Callable(self, "_on_brake_click"))
	%ReverseButton.toggled.connect(Callable(self, "_on_reverse_click"))
#endregion

func _on_brake_change(new_brake: bool):
	Loggie.info("Brake mode: %s" % new_brake)
	if new_brake:
		self.curr_train.motor.speed.target = 0.0
func _on_reverse_change(new_reverse: bool):
	Loggie.info("Reverse mode: %s" % new_reverse)
	
#region Callables
func _on_brake_click(_state: bool):
	self.brake = !self.brake
	self._on_brake_change(self.brake)
	
func _on_reverse_click(_state: bool):
	self.reverse = !self.reverse
	self._on_reverse_change(self.reverse)
	
func _on_train_entered(train3d: Train3D):
	self.curr_train = train3d
	
func _on_train_exited():
	self.curr_train = null
#endregion
