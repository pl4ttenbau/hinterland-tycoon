## Shared formatting/assets for inventory widgets; no inventory mutation lives here.
class_name InventoryPresentation extends RefCounted

static var _icons: Dictionary = {}

static func quantity(amount: float) -> String:
	return str(int(amount)) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount

static func destination(stop: int) -> String:
	if stop < 0:
		return "Unassigned"
	if is_instance_valid(Managers.interchanges):
		var station: AbstractStation = Managers.interchanges.stops_by_num.get(stop)
		if station != null:
			return "%s · #%d" % [station.station_name, stop]
	return "Stop #%d" % stop

static func icon(key: StringName) -> Texture2D:
	if not _icons.has(key):
		var path: String = "res://assets/icons/goods/generated/48/%s.png" % key
		if not ResourceLoader.exists(path):
			var good: BaseGoodsType = GameTypes.resource_types.get(key)
			var category: String = BaseGoodsType.ResourceCategory.keys()[good.res_cat] if good != null else "FREIGHT"
			path = BaseGoodsType.get_cat_image_path(category)
		_icons[key] = load(path) as Texture2D
	return _icons[key]
