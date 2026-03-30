@tool
class_name GameDialog extends Control

@export var dialog_key: String

@export var title_text: String = "Dialog":
	get(): return title_text
	set(value):
		title_text = value
		%Headline.text = value

@export var success_btn_text: String = "OK":
	get(): return success_btn_text
	set(value):
		success_btn_text = value
		%OkButton.text = value

func _init():
	if ! Engine.is_editor_hint():
		# self.dialog_key = key
		self.show_dialog()
	
	
func show_dialog(): 
	UiState.current_diag = self

func close():
	Loggie.info("Dialog closing..")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	UiState.current_diag = null
	self.queue_free()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		self.close()
