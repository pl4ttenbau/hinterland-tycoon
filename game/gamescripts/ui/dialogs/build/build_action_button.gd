## Opens one placement tool from the build picker. Hidden when the tool is unavailable here.
class_name BuildActionButton extends BuildPickerOption

@export var tool: Enums.BuildToolChoice = Enums.BuildToolChoice.NONE
## Optional image for the picker's preview panel.
@export var preview_texture: Texture2D
@export_multiline var description: String


func _ready() -> void:
	if not BuildTools.available(tool):
		hide()
		return
	var caption: String = BuildTools.title(tool)
	if not caption.is_empty():
		text = caption


func preview_image() -> Texture2D:
	return preview_texture


func preview_details() -> String:
	return description


func _on_pressed() -> void:
	choice_selected.emit(BuildChoice.of_tool(tool))
