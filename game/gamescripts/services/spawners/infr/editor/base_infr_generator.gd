@tool
@icon("res://assets/icons/icon_gears_white.png")
class_name BaseInfrGenerator extends Node

func get_map_name():
	var editor_map_name = EditorUtils.get_editor_map_name()
	if ! editor_map_name:
		Loggie.error("Cannot generate editor infrastructure: cannot get open editor map")
		return null
	return editor_map_name

func get_infr_container() -> GeneratedInfrContainer:
	var infr_container = EditorInterface.get_edited_scene_root().find_child("EditorInfr", true)
	if ! infr_container: push_error("Cannt find Node \"EditorInfr\"")
	return infr_container as GeneratedInfrContainer
