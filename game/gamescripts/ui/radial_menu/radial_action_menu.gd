@warning_ignore("missing_tool")
class_name RadialActionMenu extends Control

const ITEMS = [
	{
		"title": "Place",
		"id": "Place",
		"texture": preload("res://assets/icons/icon_build_white.png")
	},
	{
		"title": "Connect",
		"id": "Connect",
		"texture": preload("res://assets/icons/icon_fork_white.png")
	},
	{
		"title": "Enter",
		"id": "Enter",
		"texture": preload("res://assets/icons/icon_door_white.png")
	},
	{
		"title": "Company",
		"id": "Company",
		"texture": preload("res://assets/icons/icon_company_white.png")
	},
	{
		"title": "Game Menu",
		"id": "Game Menu",
		"texture": preload("res://assets/icons/icon_menu_white.png")
	},
	{
		"title": "Inventory",
		"id": "LoadUnload",
		"texture": preload("res://assets/icons/icon_good_white.png")
	}
]

func _ready() -> void:
	%RadialMenu.set_items(ITEMS)
	# connect to signals
	%RadialMenu.item_selected.connect(Callable(self, "_on_radial_action_selected"))
	%RadialMenu.item_hovered.connect(Callable(self, "_on_radial_action_hovered"))

func show_label(action_text: String):
	%HoveredActionOuter.visible = true
	%HoveredActionLabel.text = action_text

func hide_label():
	%HoveredActionLabel.text = ""
	%HoveredActionOuter.visible = false

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			if event.is_pressed() && !%RadialMenu.visible:
				%RadialMenu.open_menu(get_viewport_rect().size / 2.0)
			elif event.is_released():
				%RadialMenu.close_menu()
				self.hide_label()

func _on_radial_action_selected(key: Variant, _position: Variant):
	SignalBus.action_menu_triggered.emit(key)
	self.hide_label()

func _on_radial_action_hovered(item):
	self.show_label(item.title)
	Loggie.info(item)
