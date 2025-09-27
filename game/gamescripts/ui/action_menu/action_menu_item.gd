@tool
class_name ActionMenuItem extends HBoxContainer

signal selected()
signal unselected()

@export var icon: Texture2D:
	set(value):
		icon = value
		self.update_icon(value)
	get(): return icon
		
@export var text: String:
	set(value):
		text = value
		self.update_label_text(value)
	get(): return text
	
func _enter_tree() -> void:
	self.selected.connect(Callable(self, "_on_selected"))
	self.unselected.connect(Callable(self, "_on_unselected"))
	
#region Update Icon & Text
func update_icon(icon_tex: Texture2D):
	$Icon.texture = icon_tex
	
func update_label_text(label_text: String):
	$Label.text = label_text
#endregion

#region Selection
func _on_selected():
	self.get_label().add_theme_color_override("font_color", Color.ORANGE)
	self.get_icon_rect().visible = true
	
func _on_unselected():
		self.get_label().remove_theme_color_override("font_color")
		self.get_icon_rect().visible = false
#endregion

#region Getters
func get_icon_rect() -> TextureRect: return $Icon as TextureRect
	
func get_label() -> Button: return $Label as Button
	
func get_action_name() -> String: return self.get_label().text
#endregion
