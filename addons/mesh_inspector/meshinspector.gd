@tool
extends EditorPlugin

var inspector_plugin: MeshInspectorPlugin

func _enter_tree():
	inspector_plugin = MeshInspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree():
	remove_inspector_plugin(inspector_plugin)
