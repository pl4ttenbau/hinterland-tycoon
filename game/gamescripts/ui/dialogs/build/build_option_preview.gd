## Shows the highlighted build option: its image (an empty square until one
## exists), its name and details.
class_name BuildOptionPreview extends VBoxContainer

@onready var _image: TextureRect = %Image
@onready var _title: Label = %Title
@onready var _details: Label = %Details


## Null clears the panel, e.g. for a category with nothing to build here.
func show_option(option: BuildPickerOption) -> void:
	_image.texture = option.preview_image() if option != null else null
	_title.text = option.preview_title() if option != null else ""
	_details.text = option.preview_details() if option != null else ""
