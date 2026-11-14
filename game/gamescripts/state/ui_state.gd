@icon("uid://r84qkk5fcxhq")
extends Node

# Main menu
@export var in_main_menu: bool = true

@export var main_menu_root: StartmenuRoot = null

@export var main_menu_scene: StartmenuSubscene

@export var movement_blocked: bool = false:
	get: return movement_blocked or not _world_input_owners.is_empty()

## The most recently mounted dialog receives dialog input, including Escape.
var current_diag: GameDialog:
	get: return _open_dialogs.back() if not _open_dialogs.is_empty() else null

@export var ui_mode: Enums.UiMode = Enums.UiMode.WALKING
@export_storage var build_infr_mode: UiModeBuildInfr

var _open_dialogs: Array[GameDialog] = []
# Each owner suspends the avatar it found when opening. Modal and radial UI can overlap.
var _world_input_owners: Dictionary[Node, PlayerAvatar] = {}
var _resume_mouse_mode: Input.MouseMode


func register_dialog(dialog: GameDialog) -> void:
	_open_dialogs.append(dialog)


func unregister_dialog(dialog: GameDialog) -> void:
	_open_dialogs.erase(dialog)


func is_world_input_blocked() -> bool:
	return in_main_menu or current_diag != null or movement_blocked


func block_world_input(owner: Node) -> void:
	if _world_input_owners.has(owner):
		return
	if _world_input_owners.is_empty():
		_resume_mouse_mode = Input.mouse_mode
	var player := GlobalState.player
	_world_input_owners[owner] = player
	if is_instance_valid(player):
		player.suspend_walking(owner)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func release_world_input(owner: Node) -> void:
	if not _world_input_owners.has(owner):
		return
	var player: PlayerAvatar = _world_input_owners[owner]
	_world_input_owners.erase(owner)
	if is_instance_valid(player):
		player.resume_walking(owner)
	if _world_input_owners.is_empty():
		Input.mouse_mode = _resume_mouse_mode


## A vehicle handoff during a modal changes the mode to restore on the final release.
func set_gameplay_mouse_mode(mode: Input.MouseMode) -> void:
	if not _world_input_owners.is_empty():
		_resume_mouse_mode = mode
	elif not movement_blocked and current_diag == null:
		Input.mouse_mode = mode
