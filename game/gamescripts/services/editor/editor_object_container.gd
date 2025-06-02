@icon("res://assets/icons/icon_editor.png")
extends Node3D

func _ready():
	if ! Engine.is_editor_hint():
		self.visible = false
