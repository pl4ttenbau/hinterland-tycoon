extends VBoxContainer

signal option_selected(building: PackedScene, preview_scene: PackedScene, model_transform: Transform3D)


func _ready() -> void:
	for category: Node in get_children():
		if category is VBoxContainer:
			for child: Node in category.get_children():
				if child is BuildOptionButton:
					child.option_selected.connect(_on_option_selected)


## The category signal names a group authored in the option list scene.
func show_category(category_name: StringName) -> void:
	var has_options: bool = false
	for child: Node in get_children():
		if child is VBoxContainer:
			child.visible = child.name == category_name
			if child.visible:
				for option: Node in child.get_children():
					if option is BuildOptionButton and option.visible:
						has_options = true
						break
	$Empty.visible = not has_options


func _on_option_selected(building: PackedScene, preview_scene: PackedScene, model_transform: Transform3D) -> void:
	option_selected.emit(building, preview_scene, model_transform)
