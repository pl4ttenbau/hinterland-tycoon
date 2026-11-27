## Traction lever for the train the player is driving: sets the target speed as a percentage of the
## consist's maximum speed. The train then accelerates or brakes towards it on its own (TrainMovement).
class_name SpeedSlider extends CenterContainer

## Train the player is driving; null while on foot.
@export var current_train: Train3D

func _ready() -> void:
	SignalBus.player_entered_train.connect(self._on_player_entered_train)
	SignalBus.player_exited_train.connect(self._on_player_exited_train)
	%VSlider.value_changed.connect(self._on_speed_slider_change)
	self._sync_from_train()

## Show the train's own target rather than whatever the lever showed for the previous train,
## without echoing the value back as a new driver request.
func _sync_from_train() -> void:
	var has_train: bool = is_instance_valid(self.current_train) and is_instance_valid(self.current_train.movement)
	%VSlider.editable = has_train
	if has_train:
		%VSlider.set_value_no_signal(self.current_train.movement.speed.target * 100.0)

#region Callbacks
func _on_speed_slider_change(percentage: float) -> void:
	if not is_instance_valid(self.current_train) or not is_instance_valid(self.current_train.movement):
		Loggie.warn("Cannot change vehicle speed: no player train registered")
		return
	self.current_train.movement.speed.target = percentage / 100.0

## Code can change the target too (a depot rollout ends at 0), so the lever follows it.
func _on_target_changed(_value: float) -> void:
	self._sync_from_train()

func _on_player_entered_train(train: Train3D) -> void:
	self._disconnect_train()
	self.current_train = train
	if is_instance_valid(train) and is_instance_valid(train.movement):
		train.movement.speed.target_changed.connect(self._on_target_changed)
	self._sync_from_train()

func _on_player_exited_train() -> void:
	self._disconnect_train()
	self.current_train = null
	self._sync_from_train()
#endregion

func _disconnect_train() -> void:
	if is_instance_valid(self.current_train) and is_instance_valid(self.current_train.movement):
		var train_speed: VehicleSpeed = self.current_train.movement.speed
		if train_speed.target_changed.is_connected(self._on_target_changed):
			train_speed.target_changed.disconnect(self._on_target_changed)

func _exit_tree() -> void:
	self._disconnect_train()
