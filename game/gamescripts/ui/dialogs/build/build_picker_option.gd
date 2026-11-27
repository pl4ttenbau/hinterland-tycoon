## Base for entries in the build picker. Reports its BuildChoice when pressed and
## asks the picker's preview panel to show it when hovered or focused.
class_name BuildPickerOption extends Button

signal choice_selected(choice: BuildChoice)
signal highlighted(option: BuildPickerOption)


## Wired here so subclasses keep their own _ready.
func _init() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_highlighted)
	focus_entered.connect(_on_highlighted)


## Override: the image shown in the preview panel, or null for none.
func preview_image() -> Texture2D:
	return null


## Override: the preview panel's heading.
func preview_title() -> String:
	return text


## Override: a short text under the preview heading.
func preview_details() -> String:
	return ""


## Override: emit choice_selected with this option's BuildChoice.
func _on_pressed() -> void:
	pass


func _on_highlighted() -> void:
	highlighted.emit(self)
