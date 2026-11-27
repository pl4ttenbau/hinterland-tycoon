## Category tabs of the build picker. Names match the groups in BuildOptionList.
class_name BuildCategoryTabs extends CategoryTabs

signal category_selected(category: StringName)

const CATEGORIES := [&"Industry", &"Station", &"Rail", &"Road"]
const ICONS := [
	preload("res://assets/icons/icon_industry_white.png"),
	preload("res://assets/icons/icon_station_white.png"),
	preload("res://assets/icons/icon_rail_track_white.png"),
	preload("res://assets/icons/icon_road_white.png"),
]


func _ready() -> void:
	# 1. Base layout.
	super._ready()
	# 2. Content: one tab per category, in option-list order.
	for index: int in CATEGORIES.size():
		add_tab(CATEGORIES[index], ICONS[index])
	# 3. Wiring: republish the category name whenever the tab changes.
	tab_changed.connect(_on_tab_changed)


func publish_selection() -> void:
	category_selected.emit(CATEGORIES[current_tab])


func _on_tab_changed(_index: int) -> void:
	publish_selection()
