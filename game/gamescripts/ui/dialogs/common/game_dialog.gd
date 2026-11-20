@tool
## Shared registration, Escape handling and result delivery for gameplay dialogs.
class_name GameDialog extends Control

## Both signals carry the result while the dialog is still in the tree.
signal before_closed(result: Variant)
signal closed(result: Variant)

## How the frame's status line reads. Each tone is a label style in the theme.
enum StatusTone { HINT, ERROR, SUCCESS, ACCENT }

const STATUS_STYLES: Dictionary = {
	StatusTone.HINT: &"MutedLabel",
	StatusTone.ERROR: &"ErrorLabel",
	StatusTone.SUCCESS: &"SuccessLabel",
	StatusTone.ACCENT: &"AccentLabel",
}

## Leave this null when canceling. Set it before closing to return a selection.
@export var diag_result: Variant
@export var dialog_key: String

@export var title_text: String = "Dialog":
	set(value):
		title_text = value
		var heading := get_node_or_null("%Headline") as Label
		if heading != null:
			heading.text = value

@export var success_btn_text: String = "OK":
	set(value):
		success_btn_text = value
		var button := get_node_or_null("%OkButton") as Button
		if button != null:
			button.text = value

var _closing := false


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		UiState.register_dialog(self)
		_wire_cancel_button()


## The shared frames carry a %CancelButton that closes without a result. Wired
## here, not in _ready, because many dialogs override _ready without super().
## The guard covers re-entry after a reparent.
func _wire_cancel_button() -> void:
	var cancel := get_node_or_null("%CancelButton") as Button
	if cancel != null and not cancel.pressed.is_connected(close_all):
		cancel.pressed.connect(close_all)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		UiState.unregister_dialog(self)


## Shows a message in the dialog's %Status line: errors, results, the current
## state or a hint. An empty message hides the line.
func show_status(message: String, tone: StatusTone = StatusTone.HINT) -> void:
	var status := get_node_or_null("%Status") as Label
	if status == null:
		push_warning("%s has no %%Status label for: %s" % [name, message])
		return
	status.text = message
	status.theme_type_variation = STATUS_STYLES[tone]
	status.visible = not message.is_empty()


func clear_status() -> void:
	show_status("")


## Closes and hands the result to the before_closed and closed listeners.
func close_with(result: Variant) -> void:
	diag_result = result
	close_all()


## Guard before notifying listeners so a second close in the same frame is harmless.
func close_all() -> void:
	if _closing:
		return
	_closing = true
	before_closed.emit(diag_result)
	closed.emit(diag_result)
	queue_free()


func _input(event: InputEvent) -> void:
	if UiState.current_diag == self and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_all()
