@tool
@icon("res://assets/icons/nodes_3d/icon_vegetation.svg")
class_name EditorVegetation extends Node3D

@export_group("Editor Preview")
## Affects only the editor viewport; gameplay vegetation remains enabled.
@export var show_grass: bool = true:
	set(value):
		show_grass = value
		_queue_preview_update()
@export var show_wheat: bool = true:
	set(value):
		show_wheat = value
		_queue_preview_update()

@export_group("Vegetation Actions")
## Uses saved roads/tracks and terrain; save infrastructure JSON before rebuilding.
@export_tool_button("Regenerate Grass & Wheat Maps")
var regenerate_vegetation_maps_button = Callable(self, "regenerate_vegetation_maps")

var _bake_running: bool = false

func _ready() -> void:
	_queue_preview_update()

func _queue_preview_update() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		_apply_editor_preview.call_deferred()

func _apply_editor_preview(refresh: bool = false) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var scene: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(scene) or not scene.is_ancestor_of(self):
		return
	for layer: Node in get_tree().get_nodes_in_group(&"_terrain_vegetation"):
		if not scene.is_ancestor_of(layer):
			continue
		layer.set_editor_preview_enabled(show_wheat if layer.get_vegetation_layer() == &"wheat" else show_grass)
		if refresh:
			layer.rebuild()

func regenerate_vegetation_maps() -> void:
	if not Engine.is_editor_hint() or _bake_running:
		return
	var tool_path: String = "res://tools/grass/grass_map_regenerator.gd"
	if not FileAccess.file_exists(tool_path):
		push_warning("Vegetation regeneration requires the optional local tools/grass folder.")
		return
	_bake_running = true
	var regenerator: Script = load(tool_path)
	if regenerator == null or not regenerator.can_instantiate():
		push_error("Cannot load the local vegetation regeneration tool.")
		_bake_running = false
		return
	var succeeded: bool = await regenerator.regenerate(self)
	if succeeded:
		_apply_editor_preview(true)
	_bake_running = false

