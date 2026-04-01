class_name VehicleListItemUi extends PanelContainer

signal clicked()

@export_storage var parent_list: VehicleListUi
@export_storage var is_ready: bool = false
@export var is_highlighted: bool = false

@export var headline_text: String:
	get(): return headline_text
	set(value):
		headline_text = value
		%VehTypeLabel.text = value

@export var veh_type_key: String:
	get(): return veh_type_key
	set(value):
		veh_type_key = value
		set_vehicle_image()

#region Initialization
func _ready() -> void:
	self.clicked.connect(Callable(self, "_on_button_pressed"))
	SignalBus.dialog_vehicle_selection.connect(Callable(self, "_on_vehicle_selected"))
	self.is_ready = true

func set_vehicle_image():
	if self.veh_type_key:
		var veh_type_obj := VehicleTypeData.get_by_key(self.veh_type_key)
		var preview_tex: Texture = load(veh_type_obj.get_preview_img_path())
		%PreviewTextureRect.texture = preview_tex
#endregion

#region Highlighting
func highlight():
	self.is_highlighted = true
	%SelectedHighlighting.visible = true

func unhighlight():
	%SelectedHighlighting.visible = false
#endregion

#region Callbacks & Events
func _on_button_pressed() -> void:
	Loggie.info("Vehicle Selected: %s" % self.headline_text)
	SignalBus.dialog_vehicle_selection.emit(self.veh_type_key)
	
func _on_vehicle_selected(_veh_type_key: String):
	if (_veh_type_key == self.veh_type_key):
		self.highlight()
	elif self.is_highlighted:
		self.unhighlight()
	
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.is_pressed()):
		self.clicked.emit()
		get_viewport().set_input_as_handled()
#endregion
