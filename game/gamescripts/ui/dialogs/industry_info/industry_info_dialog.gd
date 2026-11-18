class_name IndustryDialog extends ModalGameDialog

var industry_view: Industry3D
var _recipe: IndustryType
var _inventory: GoodsInventory
var _reserves: Array[MineralReserve] = []

func _ready() -> void:
	dialog_key = "IndustryDialog"
	if not is_instance_valid(industry_view) or industry_view.industry == null or industry_view.industry.ind_type == null:
		close_all()
		return

	var industry: IndustryData = industry_view.industry
	_recipe = industry.ind_type
	_inventory = industry_view.get_inventory()
	_reserves = industry.mine_reserves
	%MineReserves.visible = not _reserves.is_empty()
	set_process(not _reserves.is_empty())
	%NameAndTypeBox.industry = industry
	%IndustryStationList.industry = industry
	%CloseButton.pressed.connect(close_all)
	%CloseButton.grab_focus()

	# Both recipe tables read the same stock as the production cycle.
	if _inventory != null:
		_inventory.goods_change.connect(_refresh_recipe)
	_refresh_recipe()
	if not _reserves.is_empty():
		_refresh_reserves()

func _process(_delta: float) -> void:
	# A nearby mine may drain shared cells into a different inventory.
	_refresh_reserves()

func _refresh_reserves() -> void:
	var remaining: float = MineralReserve.total(_reserves)
	%MineReserves.text = "Deposit worked out" if remaining <= 0.0 else "Remaining reserves · %.2f units" % remaining

func _refresh_recipe() -> void:
	%IndustryProduction.show_recipe(_recipe, _inventory)
	%IndustryConsumption.show_recipe(_recipe, _inventory)

func _exit_tree() -> void:
	if _inventory != null and _inventory.goods_change.is_connected(_refresh_recipe):
		_inventory.goods_change.disconnect(_refresh_recipe)
	super()
