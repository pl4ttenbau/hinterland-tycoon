## Summary of a previewed split or join, with Cancel and Confirm.
class_name CouplingConfirmBar extends HBoxContainer

signal confirmed()
signal cancelled()

@onready var summary: Label = %Summary
@onready var confirm: Button = %ConfirmButton

func _ready() -> void:
	%CancelButton.pressed.connect(_on_cancel_button_pressed)
	confirm.pressed.connect(_on_confirm_button_pressed)

func set_action(text: String) -> void:
	confirm.text = text

## A non-empty problem is appended to the summary and blocks confirmation.
func show_preview(description: String, problem: String) -> void:
	summary.text = description if problem.is_empty() else description + "\n" + problem
	confirm.disabled = not problem.is_empty()

func _on_cancel_button_pressed() -> void:
	cancelled.emit()

func _on_confirm_button_pressed() -> void:
	confirmed.emit()
