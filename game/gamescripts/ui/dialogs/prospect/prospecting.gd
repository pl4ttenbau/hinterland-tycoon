## Opens the player-facing survey and marker dialogs.
class_name Prospecting extends RefCounted

const DIALOG := preload("res://scenes/ui/dialogs/prospect/prospect_dialog.tscn")


static func open_at_player() -> bool:
	var player: PlayerAvatar = GlobalState.player
	if not is_instance_valid(player):
		return false
	if player.control.is_in_vehicle():
		_show_message(player, "Step out of the vehicle to prospect.")
		return true

	var manager: ProspectingManager = Managers.prospecting
	var world: WorldMapScene = GlobalState.world_container
	var player_position: Vector3 = player.walking_position()
	var world_pos := Vector2(player_position.x, player_position.z)
	if not is_instance_valid(world) or not is_instance_valid(manager) or not manager.ground_position(world_pos).is_finite():
		_show_message(player, "There is no terrain to prospect here.")
		return true

	var dialog := DIALOG.instantiate() as ProspectDialog
	dialog.can_prospect = true
	dialog.readings = manager.readings_near(world_pos)
	# Capture the player's X/Z on open so the button always surveys the same spot.
	dialog.prospect_requested.connect(func():
		if is_instance_valid(manager) and world == GlobalState.world_container:
			dialog.show_readings(manager.survey(world_pos))
	)
	world.add_child(dialog)
	return true


static func open_marker(marker_num: int) -> bool:
	var manager: ProspectingManager = Managers.prospecting
	if UiState.current_diag != null or not is_instance_valid(manager):
		return false
	var marker: SurveyMarker3D = manager.get_marker(marker_num)
	if marker == null:
		return false
	var dialog := DIALOG.instantiate() as ProspectDialog
	dialog.readings = marker.readings
	marker.get_parent().add_child(dialog)
	return true


static func _show_message(player: PlayerAvatar, message: String) -> void:
	var dialog := DIALOG.instantiate() as ProspectDialog
	dialog.message = message
	player.get_tree().root.add_child(dialog)
