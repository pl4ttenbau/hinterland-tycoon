@tool
class_name TransferInventoryRowUi extends PanelContainer

signal side_switched(is_left: bool)

signal goods_amount_set(amount_dto: GoodsAmount)

signal transfer_out(res_key: String, amount: float)

## needed to know, on which side transfer buttons are shown
@export var is_left: bool:
	get(): return is_left
	set(value):
		is_left = value
		self.side_switched.emit(value)
		self.hide_left_right()

@export_storage var goods_amount: GoodsAmount:
	get(): return goods_amount
	set(value):
		goods_amount = value
		goods_amount_set.emit(value)

@export var res_key: String:
	get(): return goods_amount.res_key
	set(value): Loggie.error("Cannot set res_key: write-only")

@export var res_amount: float:
	get(): return goods_amount.amount
	set(value): Loggie.error("Cannot set res_amount: write-only")

#region Initialization
func _init() -> void:
	# connect to own signals
	var side_switched_callable := Callable(self, "_on_side_switched")
	if !self.side_switched.is_connected(side_switched_callable):
		self.side_switched.connect(side_switched_callable)
	var goods_amount_set_callable = Callable(self, "_on_goods_amount_set")
	if !self.goods_amount_set.is_connected(goods_amount_set_callable):
		self.goods_amount_set.connect(goods_amount_set_callable)

func _ready() -> void:
	# connect transfer buttons
	self._connect_to_transfer_buttons()

func _connect_to_transfer_buttons():
	# move five
	var move_5_callable := Callable(self, "_on_move_5_btn_click")
	if !%Move5Btn_L.button_down.is_connected(move_5_callable):
		%Move5Btn_L.button_down.connect(move_5_callable)
	if !%Move5Btn_R.button_down.is_connected(move_5_callable):
		%Move5Btn_R.button_down.connect(move_5_callable)#
	# move one
	var move_1_callable := Callable(self, "_on_move_1_btn_click")
	if !%Move1Btn_L.button_down.is_connected(move_1_callable):
		%Move1Btn_L.button_down.connect(move_1_callable)
	if !%Move1Btn_R.button_down.is_connected(move_1_callable):
		%Move1Btn_R.button_down.connect(move_1_callable)

func hide_left_right():
	Loggie.info("hidng")
	%MoveLeftContainer.visible = !self.is_left
	%MoveRightContainer.visible = self.is_left
#endregion

#region Callables
func _on_move_5_btn_click():
	Loggie.info("Moving out 5 of %s" % self.res_key)
	self.transfer_out.emit(self.res_key, 5.0)

func _on_move_1_btn_click():
	Loggie.info("Moving out 1 of %s" % self.res_key)
	self.transfer_out.emit(self.res_key, 1.0)

func _on_goods_amount_set(amount_dto: GoodsAmount):
	# set resource name label
	var good_type_obj: BaseGoodsType = BaseGoodsType.get_by_key(amount_dto.res_key)
	%GoodTypeLabel.text = good_type_obj.get_display_text()
	# and amount label
	%GoodAmountLabel.text = "%.1f" % amount_dto.amount
#endregion
