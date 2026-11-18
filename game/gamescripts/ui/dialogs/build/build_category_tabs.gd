extends CategoryTabs

signal category_selected(category: StringName)

const CATEGORIES := [&"Industry", &"Station", &"Misc"]
const ICONS := [
	preload("res://assets/icons/icon_industry_white.png"),
	preload("res://assets/icons/icon_station_white.png"),
	preload("res://assets/ui/icons/actions/build.svg"),
]


func _ready() -> void:
	super._ready()
	for index: int in CATEGORIES.size():
		add_tab(CATEGORIES[index], ICONS[index])
	tab_changed.connect(_on_tab_changed)


func publish_selection() -> void:
	category_selected.emit(CATEGORIES[current_tab])


func _on_tab_changed(_index: int) -> void:
	publish_selection()
