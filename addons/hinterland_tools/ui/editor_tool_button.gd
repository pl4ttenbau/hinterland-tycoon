@tool
## One tool in the HinterlandTycoon toolbar: icon and label, toggled within the panel's ButtonGroup.
##
## The active tool is shown as a raised (non-flat) button with its icon tinted like the pressed label;
## every other tool stays flat. (Earlier versions used the icon slot for a checkmark instead, which left
## the tools without icons.)
extends Button

## Icon from the Godot editor theme, e.g. &"ToolSelect" or &"Add", used when the scene sets no `icon`.
## Editor icons only exist inside the editor, so in headless tests the button simply has no icon.
@export var editor_icon: StringName = &""

## Icon size in the toolbar, before the editor's display scale: the size of Godot's own editor icons.
## The project's white icons are 32 px; this draws them at the same size as the built-in ones.
const ICON_SIZE: int = 16

func _ready() -> void:
	## Scale with the editor UI (Editor Settings > Interface > Display Scale), like built-in icons do.
	var ui_scale: float = EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0
	add_theme_constant_override("icon_max_width", roundi(ICON_SIZE * ui_scale))
	if icon == null and editor_icon != &"" and Engine.is_editor_hint():
		icon = EditorInterface.get_editor_theme().get_icon(editor_icon, &"EditorIcons")
	toggled.connect(_sync_appearance.unbind(1))
	theme_changed.connect(_sync_appearance)
	# Silent resets (Free Tool, scene changes) set button_pressed without emitting toggled; they redraw.
	draw.connect(_sync_appearance)
	_sync_appearance()

func _sync_appearance() -> void:
	var active: bool = toggle_mode and button_pressed
	# Compare first: setting these unconditionally from a draw callback would request endless redraws.
	if flat != (not active):
		flat = not active
	for state: String in ["pressed", "hover_pressed"]:
		var tint: Color = get_theme_color("font_" + state + "_color", "Button")
		var color_name: String = "icon_" + state + "_color"
		if get_theme_color(color_name, "Button") != tint:
			add_theme_color_override(color_name, tint)
