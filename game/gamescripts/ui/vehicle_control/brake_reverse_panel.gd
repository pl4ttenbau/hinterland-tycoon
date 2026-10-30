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
	SignalBus.player_entered_train.connect(_on_train_entered)
	SignalBus.player_exited_train.connect(_on_train_exited)
	%BrakeButton.toggled.connect(_on_brake_click)
	%ReverseButton.toggled.connect(_on_reverse_click)
	_update_controls()
#endregion

func _update_controls() -> void:
	var has_train := is_instance_valid(curr_train) and is_instance_valid(curr_train.motor)
	%BrakeButton.disabled = not has_train
	%ReverseButton.disabled = not has_train
	brake = curr_train.motor.speed.brake_applied if has_train else false
	## Read the train state so rejected reversals and train changes display correctly.
	self.reverse = self.curr_train.is_reversed if has_train else false
	%BrakeButton.set_pressed_no_signal(brake)
	%ReverseButton.set_pressed_no_signal(reverse)
	%BrakeLamp.texture = LAMP_AMBER if brake else LAMP_OFF
	%ReverseLamp.texture = LAMP_GREEN if has_train and reverse else LAMP_OFF
	%ReverseStatus.text = "Reverse" if reverse else "Forward"
	%BrakeStatus.text = "Applied" if brake else "Released"
	%BrakeStatus.add_theme_color_override("font_color", Color("edb75d") if brake else Color("abb7a1"))
	%BrakeButton.tooltip_text = "Service brake: slows and holds the train. Release to resume the selected target speed."

func _on_brake_click(applied: bool) -> void:
	if not is_instance_valid(curr_train) or not is_instance_valid(curr_train.motor):
		_update_controls()
		return
	curr_train.motor.speed.brake_applied = applied

func _on_brake_changed(_applied: bool) -> void:
	_update_controls()

func _on_reverse_click(state: bool) -> void:
	if not is_instance_valid(curr_train) or not is_instance_valid(curr_train.motor):
		_update_controls()
		return
	reverse = state
	curr_train.reverse_from_current_spot()
	_update_controls()

func _disconnect_train() -> void:
	if is_instance_valid(curr_train) and is_instance_valid(curr_train.motor):
		var train_speed: VehicleSpeed = curr_train.motor.speed
		if train_speed.brake_changed.is_connected(_on_brake_changed):
			train_speed.brake_changed.disconnect(_on_brake_changed)

func _on_train_entered(train3d: Train3D) -> void:
	_disconnect_train()
	curr_train = train3d
	curr_train.motor.speed.brake_changed.connect(_on_brake_changed)
	_update_controls()

func _on_train_exited() -> void:
	_disconnect_train()
	curr_train = null
	_update_controls()

func _exit_tree() -> void:
	_disconnect_train()
