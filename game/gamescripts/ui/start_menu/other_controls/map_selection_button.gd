class_name MapSelectionButton extends Container

signal pressed(map_key: String)

@export var map_data: MapData:
	get(): return map_data
	set(value):
		map_data = value
		%MapNameLabel.text = map_data.name

func _gui_input(event: InputEvent) -> void:
	if ! self.map_data: return
	if event is InputEventMouseButton && event.pressed:
		self.pressed.emit(self.map_data.key)
