@tool
@icon("res://assets/icons/icon_town.png")
class_name TownCenter extends HideableObject

signal town_changed(_town: TownData)

@export var town: TownData:
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
