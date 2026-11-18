class_name EnterAction extends BaseAction

func _unhandled_key_input(event: InputEvent) -> void:
	if UiState.is_world_input_blocked():
		return
	if event.is_action_pressed(&"enter_exit_vehicle") and on_trigger():
		get_viewport().set_input_as_handled()


func on_trigger() -> bool:
	super.on_trigger()
	var player := GlobalState.player
	if not is_instance_valid(player):
		return false
	if player.control.exit_vehicle():
		return true
	for train: Train3D in GlobalState.trains:
		if player.control.enter_train(train):
			return true
	Loggie.info("No boardable train found on the map")
	return false
