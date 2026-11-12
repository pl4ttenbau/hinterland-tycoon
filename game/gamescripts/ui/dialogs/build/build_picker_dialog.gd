extends MenuShellDialog


func _ready() -> void:
	dialog_key = "BuildPickerDialog"
	title_text = "Build"
	super._ready()
	# Publish the initial tab once the option list and its buttons are ready.
	%Content.get_node("Categories").publish_selection()


func _on_option_selected(building: PackedScene, preview_scene: PackedScene, model_transform: Transform3D) -> void:
	diag_result = {"building": building, "preview": preview_scene, "transform": model_transform}
	close_all()
