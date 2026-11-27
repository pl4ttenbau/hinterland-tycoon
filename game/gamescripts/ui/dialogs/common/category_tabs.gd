## Full-width category switch with native button focus and keyboard navigation.
## Tabs come from data, so they are added at runtime; each one is a CategoryTabButton scene.
class_name CategoryTabs extends HBoxContainer

signal tab_changed(index: int)

var current_tab: int = 0:
	set(value):
		var next: int = clampi(value, 0, maxi(0, _buttons.size() - 1))
		if current_tab == next:
			return
		current_tab = next
		_sync_selection()
		tab_changed.emit(current_tab)

var _buttons: Array[CategoryTabButton] = []
var _group := ButtonGroup.new()

func _ready() -> void:
	add_theme_constant_override("separation", 8)

func add_tab(title: String, icon: Texture2D, subtitle: String = "") -> void:
	var index: int = _buttons.size()
	var button := CategoryTabButton.create(title, icon, subtitle)
	button.button_group = _group
	button.pressed.connect(func(): current_tab = index)
	add_child(button)
	_buttons.append(button)
	_sync_selection()

func _sync_selection() -> void:
	for index: int in range(_buttons.size()):
		_buttons[index].set_current(index == current_tab)
