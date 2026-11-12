## Owns the picker, preview and confirmation for one attempt to place a mine.
class_name MinePlacement extends Node

const PICKER := preload("res://scenes/ui/dialogs/build/build_picker_dialog.tscn")
const RESOURCE_DIALOG := preload("res://scenes/ui/dialogs/build/mine_resource_dialog.tscn")
const FULL_RICHNESS_BATCH: float = 4.0

var _world: WorldMapScene
var _building: Industry3D


static func open_picker(world: WorldMapScene) -> bool:
	if not is_instance_valid(world) or not is_instance_valid(world.terrain) \
			or not is_instance_valid(Managers.construction) or not is_instance_valid(Managers.prospecting):
		return false
	var placement := MinePlacement.new()
	placement._world = world
	world.add_child(placement)
	var picker := PICKER.instantiate() as MenuShellDialog
	picker.closed.connect(placement._picker_closed.bind(picker), CONNECT_ONE_SHOT)
	placement.add_child(picker)
	return true


func _picker_closed(result: Variant, picker: MenuShellDialog) -> void:
	if result is Dictionary:
		# Each modal restores input on exit. Let it finish before the next one captures input.
		picker.tree_exited.connect(_start_preview.bind(result), CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	else:
		queue_free()


func _start_preview(selection: Dictionary) -> void:
	if not _can_open_dialog():
		queue_free()
		return
	var building: Node = selection.building.instantiate()
	var model: Node = selection.preview.instantiate()
	if not building is Industry3D or not model is Node3D:
		building.free()
		model.free()
		queue_free()
		return

	_building = building
	var preview := BuildPreview.new()
	preview.terrain = _world.terrain
	preview.construction = Managers.construction
	preview.model = model
	preview.model.transform = selection.transform
	preview.validate_site = _site_error
	preview.site_changed.connect(_show_survey.bind(preview))
	preview.closed.connect(_preview_closed.bind(preview), CONNECT_ONE_SHOT)
	add_child(preview)


func _show_survey(position: Vector3, preview: BuildPreview) -> void:
	var readings: Dictionary[String, float] = Managers.prospecting.readings_near(Vector2(position.x, position.z))
	var details: PackedStringArray = []
	for resource: String in readings:
		details.append("%s %s" % [ProspectDialog.resource_name(resource), ProspectDialog.richness_text(readings[resource])])
	preview.set_site_detail("Unsurveyed" if details.is_empty() else "Survey · " + " · ".join(details))


func _preview_closed(result: Variant, preview: BuildPreview) -> void:
	if result is Vector3:
		preview.tree_exited.connect(_open_resource_dialog.bind(result), CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	else:
		queue_free()


func _open_resource_dialog(position: Vector3) -> void:
	if not _can_open_dialog():
		queue_free()
		return
	var dialog := RESOURCE_DIALOG.instantiate() as MineResourceDialog
	# Use the exact selected location. A nearby survey is only a preview of the site.
	dialog.readings = Managers.prospecting.get_traces_at_pos(Vector2(position.x, position.z))
	dialog.build_requested.connect(_build_mine.bind(position, dialog))
	dialog.closed.connect(_finish, CONNECT_ONE_SHOT)
	add_child(dialog)


func _build_mine(resource: String, position: Vector3, dialog: MineResourceDialog) -> void:
	var problem: String = _site_error(position)
	if not problem.is_empty():
		dialog.show_error(problem)
		return
	var richness: float = dialog.readings.get(resource, 0.0)
	if richness <= 0.0 or not GameTypes.resource_types.has(resource):
		dialog.show_error("Choose an available resource.")
		return

	# Keep the output site-local because authored industries share their catalog recipes.
	var mesh_name: String = _building.scene_file_path.get_file().get_basename()
	var recipe := IndustryType.new("MINE", "%s mine" % ProspectDialog.resource_name(resource), mesh_name, 20, [], [])
	recipe.produces.append(TransformedGood.new(resource, FULL_RICHNESS_BATCH * richness))
	var view: Industry3D = _building
	_building = null
	Managers.industries.place_runtime_industry(view, recipe, position)
	dialog.close_all()


func _site_error(position: Vector3) -> String:
	if not is_instance_valid(Managers.industries) or not is_instance_valid(Managers.construction) or not is_instance_valid(_building):
		return "Industry construction is unavailable here."
	return Managers.construction.site_error(_world, _building, Transform3D(_building.basis, position))


func _can_open_dialog() -> bool:
	return _world == GlobalState.world_container and is_instance_valid(_world.terrain) \
		and is_instance_valid(Managers.construction) and is_instance_valid(Managers.prospecting) \
		and UiState.current_diag == null and not UiState.in_main_menu


func _finish(_result: Variant) -> void:
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_building):
		_building.free()
