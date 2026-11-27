## Homes and industries served by the interchange (or the lone stop).
class_name StationCoverageList extends ItemList

const HOUSE_ICON := preload("res://assets/icons/icon_house_white.png")
const INDUSTRY_ICON := preload("res://assets/icons/icon_industry_white.png")

func show_coverage(stop: AbstractStation) -> void:
	clear()
	var buildings: StationConnections = stop.interchange.connections if stop.interchange != null else stop.connections
	add_item("Connected homes · %d" % buildings.houses.size(), HOUSE_ICON, false)
	var industries: int = 0
	for connection: StationIndustryConnection in buildings.industries:
		var industry: IndustryData = connection.industry
		if industry != null and industry.ind_type != null:
			var industry_name: String = industry.ind_name if not industry.ind_name.is_empty() else industry.ind_type.name
			add_item(industry_name, INDUSTRY_ICON, false)
			industries += 1
	if industries == 0:
		add_item("No connected industries", INDUSTRY_ICON, false)
