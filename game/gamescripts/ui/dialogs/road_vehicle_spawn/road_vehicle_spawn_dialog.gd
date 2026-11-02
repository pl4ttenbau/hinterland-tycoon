## Road-only selection using the shared dialog frame/theme. No itinerary is assigned.
class_name RoadVehicleSpawnDialog extends ModalGameDialog

const BASE_SCENE: String = "res://scenes/ui/dialogs/default_dialog.tscn"
const SCRIPT_PATH: String = "res://game/gamescripts/ui/dialogs/road_vehicle_spawn/road_vehicle_spawn_dialog.gd"

var depot: RoadDepotData
var _types: Array[RoadVehicleTypeData] = []
var _list: ItemList
var _preview: TextureRect
var _preview_placeholder: Label
var _details: Label
var _error: Label
var _spawn_button: Button

## Reuse the existing scene's unique heading/button nodes and visual styling.
static func create(source_depot: RoadDepotData) -> RoadVehicleSpawnDialog:
	var frame: Control = load(BASE_SCENE).instantiate()
	frame.set_script(load(SCRIPT_PATH))
	var dialog: RoadVehicleSpawnDialog = frame as RoadVehicleSpawnDialog
	dialog.depot = source_depot
	return dialog

func _ready() -> void:
	dialog_key = "SpawnRoadVehicleDialog"
	title_text = "Spawn road vehicle"
	_suspend_world_input()
	_build_content()
	_build_buttons()
	_populate_vehicles()

#region Content
func _build_content() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	get_node("OuterPanel/OuterMargin/OuterVLayout/Container").add_child(content)
	var description := Label.new()
	description.text = "%s\nSpawn 10 m along the road, facing away from the depot." % depot.depot_name
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	_add_selection(content)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_details)
	_error = Label.new()
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_theme_color_override("font_color", Color("e69b86"))
	_error.hide()
	content.add_child(_error)

func _add_selection(content: VBoxContainer) -> void:
	var selection := HBoxContainer.new()
	selection.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection.add_theme_constant_override("separation", 16)
	content.add_child(selection)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(350, 180)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_vehicle_selected)
	selection.add_child(_list)
	var visual := VBoxContainer.new()
	visual.custom_minimum_size.x = 260
	selection.add_child(visual)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(260, 160)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual.add_child(_preview)
	_preview_placeholder = Label.new()
	_preview_placeholder.text = "No preview available"
	_preview_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual.add_child(_preview_placeholder)

func _build_buttons() -> void:
	_spawn_button = get_node("%OkButton")
	_spawn_button.text = "Spawn vehicle"
	_spawn_button.pressed.connect(_spawn_selected)
	var actions := HBoxContainer.new()
	_spawn_button.get_parent().add_child(actions)
	_spawn_button.reparent(actions)
	_spawn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close_all)
	actions.add_child(cancel)

## The shared catalog also contains trains; only road types appear here.
func _populate_vehicles() -> void:
	if GameTypes.ensure_initialized() == OK:
		for type: VehicleTypeData in GameTypes.vehicle_types:
			if type is RoadVehicleTypeData:
				_types.append(type)
				_list.add_item(type.display_name)
	_spawn_button.disabled = _types.is_empty()
	if not _types.is_empty():
		_list.select(0)
		_on_vehicle_selected(0)
	_list.grab_focus()

## A model-folder preview.png is optional; adding it requires no dialog changes.
func _on_vehicle_selected(index: int) -> void:
	var type: RoadVehicleTypeData = _types[index]
	var path: String = type.get_preview_img_path()
	_preview.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_preview_placeholder.visible = _preview.texture == null
	var speed: String = "%.0f km/h" % float(type.max_speed_kmh) if type.max_speed_kmh != null else "Unspecified"
	var price: Variant = type.get_purchase_price()
	var price_text: String = "DM %d" % price if price != null else "Price unknown"
	_details.text = "Purchase price: %s\nMaximum speed: %s" % [price_text, speed]
	_details.tooltip_text = "Purchase price in game money." if price != null \
		else "Speed, motor power and transport capacity are required to calculate a price."
	_error.hide()
#endregion

#region Spawning and dialog lifecycle
func _spawn_selected() -> void:
	var selected: PackedInt32Array = _list.get_selected_items()
	if _closing or selected.is_empty():
		return
	if not is_instance_valid(Managers.vehicles):
		_show_error("Vehicle spawning is unavailable.")
		return
	var vehicle: RoadVehicle3D = Managers.vehicles.spawn_road_vehicle_at_depot(_types[selected[0]].key, depot)
	if vehicle == null:
		_show_error(Managers.vehicles.last_road_spawn_error)
		return
	diag_result = vehicle.vehicle_obj.num
	close_all()

func _show_error(message: String) -> void:
	_error.text = message
	_error.show()

#endregion
