class_name GameDialog extends Control

@export var dialog_key: String

func _init(key: String):
	self.dialog_key = key
	self.show_dialog()
	
func show_dialog(): 
	UiState.current_diag = self

func close():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	UiState.current_diag = null
	self.queue_free()
