@tool
class_name TownCenter extends Node

signal town_changed(Town)

@export var town: Town:
	set(_town):
		town = _town
		self.name = _town.to_string()
		set_label_text()
		self.town_changed.emit(_town)
	
func set_label_text():
	self.get_child(0).text = self.town.town_name

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
