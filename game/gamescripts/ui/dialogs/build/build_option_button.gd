class_name BuildOptionButton extends Button

signal option_selected(definition: IndustryBuildingType, building: PackedScene,
		preview_scene: PackedScene, model_transform: Transform3D)

@export var building_key: String

var _definition: IndustryBuildingType
var _building_scene: PackedScene
var _preview_scene: PackedScene
var _model_transform := Transform3D.IDENTITY


func _ready() -> void:
	_definition = GameTypes.industry_buildings.get(building_key)
	if _definition == null or _definition.construction_cost < 0:
		hide()
		return
	_building_scene = load(_definition.scene_path) as PackedScene
	_preview_scene = load(_definition.preview_scene_path) as PackedScene
	if _building_scene == null or _preview_scene == null:
		hide()
		return

	# Read local geometry off-tree so the live building's callbacks do not run.
	var building: Node = _building_scene.instantiate()
	var component := Constructable.find_on(building)
	var footprint: CollisionShape3D = component.placement_collision_shape if component != null else null
	if footprint == null or footprint.shape == null:
		_preview_scene = null
		hide()
	else:
		text = "%s  ·  %s" % [_definition.display_name, CompanyData.format_cash(_definition.construction_cost)]
		if component.visual_model != null:
			_model_transform = component.visual_model.transform
	building.free()


func _on_pressed() -> void:
	if _preview_scene != null:
		option_selected.emit(_definition, _building_scene, _preview_scene, _model_transform)
