@tool
class_name StartmenuButton extends Control

@export var menu_key: String

@export var menu_text: String:
	get(): return menu_text
	set(value):
		menu_text = value
		%Button.text = value
