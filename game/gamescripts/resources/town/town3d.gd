@tool
@icon("res://assets/icons/icon_town.png")
class_name Town3D extends GameEntity3D

signal town_changed(_town: TownData)

@export var town: TownData:
	set(value):
		if ! value:
			return
		town = value
		
		self.town_changed.emit(value)
	get(): return town

#region Initialization
func _init() -> void:
	var town_changed_callable: Callable = Callable(self, "_on_town_data_changed")
	if !self.town_changed.is_connected(town_changed_callable):
		self.town_changed.connect(town_changed_callable)

func set_label_text(new_name: String):
	if new_name && $SubViewport/Town3DSign:
		self.name = "Town3D_%s" % new_name
		$SubViewport/Town3DSign.town_name = new_name
#endregion

#region Callbacks
func _on_town_data_changed(town_data: TownData):
	self.name = town_data.to_string()
	set_label_text(town_data.town_name)
	self.town.town_name_changed.connect(Callable(self, "_on_town_name_changed"))

func _on_town_name_changed(town_name: String):
	self.set_label_text(town_name)
#endregion
