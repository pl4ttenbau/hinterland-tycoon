## Shared formatting/assets for inventory widgets; no inventory mutation lives here.
class_name InventoryPresentation extends RefCounted

static var _icons: Dictionary = {}

static func quantity(amount: float) -> String:
	return str(int(amount)) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount

## Each recipe line shows the quantity per batch and the stock available now.
static func fill_recipe_list(list: ItemList, rows: Array[TransformedGood], inventory: GoodsInventory, inputs: bool) -> void:
	list.clear()
	for row: TransformedGood in rows:
		var stock: String = "unavailable"
		if inventory != null:
			var amount: float = inventory.stack_amount(row.res_key) if inputs else inventory.get_amount(row.res_key)
			stock = "%s in stock" % quantity(amount)
		var label: String = "%s × %s per batch · %s" % [quantity(row.res_modifier), row.res_key.capitalize(), stock]
		list.add_item(label, null, false)
	if rows.is_empty():
		list.add_item("None", null, false)

static func destination(interchange_id: int) -> String:
	if interchange_id < 0:
		return "Unassigned"
	if is_instance_valid(Managers.interchanges):
		var interchange: InterchangeData = Managers.interchanges.by_num.get(interchange_id)
		if interchange != null:
			return interchange_label(interchange)
	return "Interchange #%d" % interchange_id

static func interchange_label(interchange: InterchangeData) -> String:
	var title: String = interchange.interchange_name
	var city: String = interchange.town_name
	if not city.is_empty() and city.nocasecmp_to(title) != 0:
		return "%s · %s" % [city, title]
	return title

static func icon(key: StringName) -> Texture2D:
	if not _icons.has(key):
		var path: String = "res://assets/icons/goods/generated/48/%s.png" % key
		if not ResourceLoader.exists(path):
			var good: BaseGoodsType = GameTypes.resource_types.get(key)
			var category: String = BaseGoodsType.ResourceCategory.keys()[good.res_cat] if good != null else "FREIGHT"
			path = BaseGoodsType.get_cat_image_path(category)
		_icons[key] = load(path) as Texture2D
	return _icons[key]
