## Full-width category switch with native button focus and keyboard navigation.
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

var _buttons: Array[Button] = []
var _indicators: Array[ColorRect] = []
var _group := ButtonGroup.new()

func _ready() -> void:
	add_theme_constant_override("separation", 8)

func add_tab(title: String, icon: Texture2D, subtitle: String = "") -> void:
	var index: int = _buttons.size()
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 82)
	button.tooltip_text = title if subtitle.is_empty() else "%s: %s" % [title, subtitle]
	button.pressed.connect(func(): current_tab = index)
	_style_button(button)
	add_child(button)
	_buttons.append(button)
	_add_content(button, title, subtitle, icon)
	var indicator := ColorRect.new()
	indicator.color = Color("dfb66c")
	indicator.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	indicator.offset_left = 16
	indicator.offset_right = -16
	indicator.offset_top = -4
	indicator.offset_bottom = -1
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(indicator)
	_indicators.append(indicator)
	_sync_selection()

func _add_content(button: Button, title: String, subtitle: String, icon: Texture2D) -> void:
	var margin := MarginContainer.new()
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(38, 38)
	row.add_child(picture)
	var captions := VBoxContainer.new()
	captions.add_theme_constant_override("separation", 0)
	if subtitle.is_empty():
		captions.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(captions)
	_add_label(captions, title, 24, Color("eee6ce"))
	if not subtitle.is_empty():
		_add_label(captions, subtitle, 16, Color("acb9a4"))
	_ignore_mouse(margin)

func _add_label(parent: Node, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _style_button(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("273c2c") if "pressed" in state else Color("111d16")
		style.border_color = Color("dfb66c") if "pressed" in state or state == "focus" else Color("465845")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		if state == "hover":
			style.bg_color = Color("243426")
		if state == "focus":
			style.draw_center = false
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)

# Content is decorative; the whole tab remains one accessible native button target.
func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in control.get_children():
		if child is Control:
			_ignore_mouse(child)

func _sync_selection() -> void:
	for index: int in range(_buttons.size()):
		_buttons[index].set_pressed_no_signal(index == current_tab)
		_indicators[index].visible = index == current_tab
