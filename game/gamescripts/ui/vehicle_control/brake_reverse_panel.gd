@icon("res://assets/icons/icon_speedometer_ui.png")
class_name BrakeReversePanel extends CenterContainer

const LAMP_OFF = preload("res://assets/ui/theme/textures/lamp_off.svg")
const LAMP_GREEN = preload("res://assets/ui/theme/textures/lamp_green.svg")
const LAMP_AMBER = preload("res://assets/ui/theme/textures/lamp_amber.svg")

@export var curr_train: Train3D

@export var brake: bool = false
@export var reverse: bool = false

#region Initialization
func _ready() -> void:
	# connect to vehicle
	SignalBus.player_entered_train.connect(Callable(self, "_on_train_entered"))
	SignalBus.player_exited_train.connect(Callable(self, "_on_train_exited"))
	# connect Brake & Reverse buttons
	%BrakeButton.toggled.connect(Callable(self, "_on_brake_click"))
	%ReverseButton.toggled.connect(Callable(self, "_on_reverse_click"))
	_refresh_indicators()
#endregion

func _on_brake_change(new_brake: bool):
	Loggie.info("Brake mode: %s" % new_brake)
	if new_brake and is_instance_valid(curr_train):
		self.curr_train.motor.speed.target = 0.0

func _on_reverse_change(new_reverse: bool):
	Loggie.info("Reverse mode: %s" % new_reverse)
	if is_instance_valid(curr_train):
		self.curr_train.reverse_from_current_spot()

func _refresh_indicators() -> void:
	%BrakeButton.set_pressed_no_signal(brake)
	%ReverseButton.set_pressed_no_signal(reverse)
	%BrakeLamp.texture = LAMP_AMBER if brake else LAMP_OFF
	%ReverseLamp.texture = LAMP_GREEN if reverse else LAMP_OFF
	%BrakeStatus.text = "Applied" if brake else "Released"
	%ReverseStatus.text = "Reverse" if reverse else "Forward"

#region Callables
func _on_brake_click(state: bool):
	self.brake = state
	_refresh_indicators()
	self._on_brake_change(self.brake)

func _on_reverse_click(state: bool):
	self.reverse = state
	_refresh_indicators()
	self._on_reverse_change(self.reverse)
	
func _on_train_entered(train3d: Train3D):
	self.curr_train = train3d
	
func _on_train_exited():
	self.curr_train = null
#endregion
