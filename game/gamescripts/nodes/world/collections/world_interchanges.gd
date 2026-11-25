@tool
@icon("res://assets/icons/icon_station_white.png")
## WorldInterchanges: the map's place for station tools, next to Residences and Industries.
##
## For now it only holds tools; the stations themselves still come from interchanges.json
## (InterchangesLoader), and their views stay with the stop loaders.
##
## In a game run from the editor, Ctrl+Shift+E writes the stops built in game into the map's
## interchanges.json (InterchangesExporter via StationCreator.export_stops). That needs the running game,
## which is why it is a key and not an inspector button: the editor cannot see stops built in a game.
class_name WorldInterchanges extends Node

## With Ctrl+Shift: hard to press by accident, and free in the game's input map.
const EXPORT_STOPS_KEY: Key = KEY_E

func _ready() -> void:
	# Only a run from the editor may write the map's res:// files; exported builds never listen at all.
	set_process_unhandled_key_input(not Engine.is_editor_hint() and OS.has_feature("editor"))

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != EXPORT_STOPS_KEY \
			or not key.ctrl_pressed or not key.shift_pressed or key.alt_pressed:
		return
	get_viewport().set_input_as_handled()
	var creator: StationCreator = null
	if is_instance_valid(Managers.interchanges):
		creator = Managers.interchanges.get_node_or_null("StationCreator") as StationCreator
	if creator == null or not creator.is_available():
		push_warning("Stop export: the station services are not loaded yet.")
		return
	creator.export_stops()
