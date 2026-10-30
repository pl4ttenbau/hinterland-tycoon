@tool
extends EditorPlugin

const STATE_AUTOLOAD_NAME = "EditorState"
const EDITOR_SIGNALS_SCRIPT = preload("res://addons/hinterland_tools/editor_signals.gd")

var editor_signals: Node

func _enable_plugin() -> void:
	# Add autoloads here.
	if Engine.is_editor_hint():
		get_tree().root.tree_entered.connect(Callable(self, "_on_root_scene_node_added"))

func _disable_plugin() -> void:
	# Remove autoloads here.
	# disconnect signals
	if Engine.is_editor_hint():
		get_tree().root.tree_entered.disconnect(Callable(self, "_on_root_scene_node_added"))

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	print("HinterlandTycoon plugin activated!")
	self.editor_signals = EDITOR_SIGNALS_SCRIPT.new()
	self.editor_signals.name = "EditorSignals"
	self.add_child(self.editor_signals)
	self.enable_editor_state()

func _exit_tree() -> void:
	print("Deactivating HinterlandTycoon plugin")
	self.remove_editor_state()

#region EditorState
func enable_editor_state():
	if ! Engine.has_singleton(STATE_AUTOLOAD_NAME):
		add_autoload_singleton(STATE_AUTOLOAD_NAME, "res://addons/hinterland_tools/editor_state.gd")

func remove_editor_state():
	if Engine.has_singleton(STATE_AUTOLOAD_NAME):
		remove_autoload_singleton(STATE_AUTOLOAD_NAME)
#endregion

#region Callables
func _on_root_scene_node_added():
	Loggie.info("Node added")
#endregion
