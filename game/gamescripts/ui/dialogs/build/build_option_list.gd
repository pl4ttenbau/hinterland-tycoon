## Build options grouped by category; each group is a VBox authored in the scene
## and named after its category tab. Buildings and placement tools alike report a BuildChoice.
class_name BuildOptionList extends VBoxContainer

signal choice_selected(choice: BuildChoice)
## The option the preview panel should show; null when the category offers nothing here.
signal option_highlighted(option: BuildPickerOption)


func _ready() -> void:
	for category: Node in get_children():
		if category is VBoxContainer:
			for child: Node in category.get_children():
				if child is BuildPickerOption:
					child.choice_selected.connect(choice_selected.emit)
					child.highlighted.connect(option_highlighted.emit)


## Shows the group named by the category tab, or the empty state if it offers
## nothing here, and previews its first option.
func show_category(category_name: StringName) -> void:
	var first: BuildPickerOption = null
	for child: Node in get_children():
		if child is VBoxContainer:
			child.visible = child.name == category_name
			if child.visible:
				for option: Node in child.get_children():
					if option is BuildPickerOption and option.visible:
						first = option
						break
	%Empty.visible = first == null
	option_highlighted.emit(first)
