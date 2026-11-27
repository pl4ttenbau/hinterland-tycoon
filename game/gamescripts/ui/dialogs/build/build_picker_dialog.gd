## Everything the player can place on the map. Closes with a BuildChoice;
## ActionHandler starts the chosen building or tool.
class_name BuildPickerDialog extends ModalGameDialog

@onready var _categories: BuildCategoryTabs = %Categories
@onready var _options: BuildOptionList = %Options
@onready var _preview: BuildOptionPreview = %Preview


func _ready() -> void:
	# 1. Wiring: tabs drive the option list; the list drives the preview and the result.
	_connect_signals()
	# 2. Initial state: show the first tab now that everything is connected.
	_categories.publish_selection()
	%CancelButton.grab_focus()


func _connect_signals() -> void:
	_categories.category_selected.connect(_options.show_category)
	_options.choice_selected.connect(_on_choice_selected)
	_options.option_highlighted.connect(_preview.show_option)


func _on_choice_selected(choice: BuildChoice) -> void:
	close_with(choice)
