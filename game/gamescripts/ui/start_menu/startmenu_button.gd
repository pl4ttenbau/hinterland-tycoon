@tool
class_name StartmenuButton extends Control

signal pressed()

@export var key: String

@export var text: String:
	get(): return text
	set(value):
		text = value
		%Button.text = value
		
#region Initialization
func _enter_tree() -> void:
	%Button.pressed.connect(Callable(self, "_on_button_pressed"))
#endregion

#region Callbacks
func _on_button_pressed():
	Loggie.info("Button click: [%s]" % self.key)
	self.pressed.emit()
#endregion
