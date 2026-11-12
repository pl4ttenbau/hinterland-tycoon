class_name BuildOptionButton extends Button

signal option_selected(building: PackedScene, preview_scene: PackedScene, model_transform: Transform3D)

@export var building_title: String
@export var building_scene: PackedScene

var _preview_scene: PackedScene
var _model_transform := Transform3D.IDENTITY


func _ready() -> void:
	if building_scene == null:
		hide()
		return
	# Read the component off-tree to avoid running the live building's _enter_tree and _ready.
	var building: Node = building_scene.instantiate()
	var component := Constructable3D.find_on(building)
	if component != null and component.preview_scene != null and component.construction_cost >= 0:
		text = "%s  ·  %d" % [building_title, component.construction_cost]
		_preview_scene = component.preview_scene
		if component.model != null:
			_model_transform = component.model.transform
	else:
		hide()
	building.free()


func _on_pressed() -> void:
	if _preview_scene != null:
		option_selected.emit(building_scene, _preview_scene, _model_transform)
