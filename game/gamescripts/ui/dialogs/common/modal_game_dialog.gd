## Shared modal lifecycle for dialogs that suspend walking and restore exact input state.
class_name ModalGameDialog extends GameDialog

var _previous_mouse_mode: Input.MouseMode
var _previous_movement_blocked: bool
var _walking_player: BasicFpsPlayer
var _walking_process_mode: Node.ProcessMode
var _closing: bool = false

func _suspend_world_input() -> void:
	_previous_mouse_mode = Input.mouse_mode
	_previous_movement_blocked = UiState.movement_blocked
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UiState.movement_blocked = true
	if is_instance_valid(GlobalState.player):
		_walking_player = GlobalState.player.player_parent
		_walking_process_mode = _walking_player.process_mode
		_walking_player.process_mode = Node.PROCESS_MODE_DISABLED

func close_all() -> void:
	if _closing:
		return
	_closing = true
	before_closed.emit(diag_result)
	closed.emit(diag_result)
	queue_free()

## Covers success, cancellation and external removal alike.
func _exit_tree() -> void:
	if is_instance_valid(_walking_player):
		_walking_player.process_mode = _walking_process_mode
	UiState.movement_blocked = _previous_movement_blocked
	Input.mouse_mode = _previous_mouse_mode
	if UiState.current_diag == self:
		UiState.current_diag = null
