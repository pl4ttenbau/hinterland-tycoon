## One full-width tab of CategoryTabs: icon, title, optional subtitle and a selection bar.
## The content is decorative; the whole tab stays one native button target.
class_name CategoryTabButton extends Button

const SCENE_PATH := "res://scenes/ui/dialogs/common/category_tab_button.tscn"

static func create(title: String, icon: Texture2D, subtitle: String = "") -> CategoryTabButton:
	var tab := (load(SCENE_PATH) as PackedScene).instantiate() as CategoryTabButton
	tab.get_node("%Title").text = title
	tab.get_node("%Subtitle").text = subtitle
	tab.get_node("%Subtitle").visible = not subtitle.is_empty()
	if subtitle.is_empty():
		tab.get_node("%Captions").alignment = BoxContainer.ALIGNMENT_CENTER
	tab.get_node("%Icon").texture = icon
	tab.tooltip_text = title if subtitle.is_empty() else "%s: %s" % [title, subtitle]
	return tab

func set_current(current: bool) -> void:
	set_pressed_no_signal(current)
	%Indicator.visible = current
