## In-game menu. Empty for now; the frame's Close button is its only control.
class_name GameMenuDialog extends ModalGameDialog

func _ready() -> void:
	%CancelButton.grab_focus()
