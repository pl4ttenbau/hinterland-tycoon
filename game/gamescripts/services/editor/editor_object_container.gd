@tool
@icon("res://assets/icons/nodes_3d/icon_editor.svg")
class_name WorldEditorObjects extends Node3D

@export var map_key: String

var json_history: Object
var _json_store: RefCounted

@export_group("Infrastructure JSON")
@export_tool_button("Load Roads JSON")
var load_roads_json = Callable(self, "do_load_roads_json")
@export_tool_button("Load Rails JSON")
var load_rails_json = Callable(self, "do_load_rails_json")

func do_load_roads_json() -> void:
	_load_json(Enums.InfrDomain.ROAD)

func do_load_rails_json() -> void:
	_load_json(Enums.InfrDomain.RAIL)

func _load_json(domain: Enums.InfrDomain) -> void:
	# Load the actual source scene, never the locked instance inside a world.
	# Keeping this action explicit avoids silently overwriting scene-side edits.
	if not Engine.is_editor_hint() or EditorInterface.get_edited_scene_root() != self:
		push_warning("Open the EditorObjects scene separately and select its root to load infrastructure JSON.")
		return
	if _json_store == null:
		_json_store = load("res://addons/hinterland_tools/infr_json_store.gd").new()
	var result: Dictionary = _json_store.load_world(self, domain, json_history)
	if not result.ok:
		push_warning(result.error)
		return
	EditorInterface.mark_scene_as_unsaved()
	print("Loaded %d %s from JSON. Save this EditorObjects scene with Ctrl+S." % [result.count, "roads" if domain == Enums.InfrDomain.ROAD else "rails"])


#region Initializaion
func _ready():
	if ! Engine.is_editor_hint(): 
		self._ingame_ready()
	else: 
		self._editor_ready()

func _editor_ready():
	pass
	
func _ingame_ready():
	self.visible = false
#endregion
