@tool
## Shared registration, Escape handling and result delivery for gameplay dialogs.
class_name GameDialog extends Control

## Both signals carry the result while the dialog is still in the tree.
signal before_closed(result: Variant)
signal closed(result: Variant)

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


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		UiState.unregister_dialog(self)


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
