@tool
extends Button

const CHECKMARK_SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M3 8l3 3 7-7" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
var _checkmark: Texture2D
var _spacer: Texture2D

func _ready() -> void:
	var image := Image.new()
	image.load_svg_from_string(CHECKMARK_SVG)
	_checkmark = ImageTexture.create_from_image(image)
	var blank := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	blank.fill(Color.TRANSPARENT)
	_spacer = ImageTexture.create_from_image(blank)
	toggled.connect(_on_toggled)
	theme_changed.connect(_sync_appearance)
	# Silent resets (Free Tool, scene changes) redraw without emitting toggled.
	draw.connect(_sync_appearance)
	_sync_appearance()

func _on_toggled(_pressed: bool) -> void:
	_sync_appearance()

func _sync_appearance() -> void:
	if _checkmark == null:
		return
	var active: bool = toggle_mode and button_pressed
	var wanted: Texture2D = _checkmark if active else _spacer
	# Identical icon sizes reserve the checkmark's space in either state.
	if icon != wanted:
		icon = wanted
	if flat != (not active):
		flat = not active
	for state: String in ["pressed", "hover_pressed"]:
		var tint: Color = get_theme_color("font_" + state + "_color", "Button")
		var color_name: String = "icon_" + state + "_color"
		if get_theme_color(color_name, "Button") != tint:
			add_theme_color_override(color_name, tint)
