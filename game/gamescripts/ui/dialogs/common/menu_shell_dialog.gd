## Empty themed modal frame; screens can add content under %Content later.
class_name MenuShellDialog extends ModalGameDialog

func _ready() -> void:
	_suspend_world_input()
	%OkButton.pressed.connect(close_all)
	%OkButton.grab_focus()
