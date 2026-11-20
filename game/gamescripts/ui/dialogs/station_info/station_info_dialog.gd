## Name, town and the Stops / Coverage / Inventory tabs of a clicked stop.
## Each tab is its own scene and fills itself from the stop.
class_name StationInfoDialog extends ModalGameDialog

var stop: AbstractStation

func _ready() -> void:
	# 1. Wiring.
	%CloseButton.pressed.connect(close_all)
	if stop == null:
		close_all()
		return
	# 2. Identity: station name with its town above it.
	title_text = stop.station_name if not stop.station_name.is_empty() else "Station"
	var city: String = stop.town_name.strip_edges()
	%TownName.text = city
	%TownName.visible = not city.is_empty()
	if city.is_empty():
		%StationNameInset.add_theme_constant_override("margin_left", 0)
	# 3. Content: each tab fills itself from the stop.
	(%Stops as StationStopsList).show_stops(stop)
	(%Coverage as StationCoverageList).show_coverage(stop)
	(%Inventory as StationStockView).show_inventory(stop)
	# 4. Focus.
	%CloseButton.grab_focus()

