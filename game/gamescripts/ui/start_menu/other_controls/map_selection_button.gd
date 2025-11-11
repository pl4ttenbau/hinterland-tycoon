class_name MapSelectionButton extends Container

signal pressed(map_key: String)

@export var map_data: MapData:
	get(): return map_data
	set(value):
		map_data = value
		%MapNameLabel.text = map_data.name
		self._load_preview_pic()
		
func _load_preview_pic():
	var preview_path: String = self.map_data.get_preview_image_path()
	var img: Image = Image.load_from_file(preview_path)
	var texture = ImageTexture.create_from_image(img)
	%PreviewImg.texture = texture

func _gui_input(event: InputEvent) -> void:
	if ! self.map_data: return
	if event is InputEventMouseButton && event.pressed:
		self.pressed.emit(self.map_data.key)
