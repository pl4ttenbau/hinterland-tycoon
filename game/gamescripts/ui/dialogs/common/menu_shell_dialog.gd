## Themed modal frame with a %Content slot and a default Close button.
class_name MenuShellDialog extends ModalGameDialog

# Derived screens call this after configuring their title and content.
func _ready() -> void:
	%OkButton.pressed.connect(close_all)
	%OkButton.grab_focus()
