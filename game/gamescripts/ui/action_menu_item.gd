@tool
class_name ActionMenuItem extends HBoxContainer

signal text_set(text: String)

signal selected()
signal unselected()

@export var icon: Texture2D

@export var text: String:
	set(value): self.text_set.emit(value)
	
func _enter_tree() -> void:
	self.text_set.connect(Callable(self, "_on_text_set"))
	self.selected.connect(Callable(self, "_on_selected"))
	self.unselected.connect(Callable(self, "_on_unselected"))

func _on_text_set(_text: String) -> void:
	self.get_label().text = _text
	
func get_icon() -> TextureRect:
	return self.get_child(0) as TextureRect
	
func get_label() -> Button:
	return self.get_child(1) as Button
	
func _on_selected():
	self.get_label().add_theme_color_override("font_color", Color.ORANGE)
	
func _on_unselected():
		self.get_label().remove_theme_color_override("font_color")
