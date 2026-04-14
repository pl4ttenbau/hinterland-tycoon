@tool
class_name TransferInventoryRowUi extends PanelContainer

signal side_switched(is_left: bool)

signal transfer_out(res_key: String, amount: float)

@export var is_left: bool:
	get(): return is_left
	set(value):
		is_left = value
		self.side_switched.emit(value)
		self.hide_left_right()

@export var res_key: String:
	get(): return res_key
	set(value):
		%GoodTypeLabel.text = value

@export var res_amount: float:
	get(): return res_amount
	set(value):
		%GoodAmountLabel.text = "%.1f" % value

#region Initialization
func _ready() -> void:
	var side_switched_callable := Callable(self, "_on_side_switched")
	if !self.side_switched.is_connected(side_switched_callable):
		self.side_switched.connect(side_switched_callable)
	# connect transfer buttons
	var move_5_callable := Callable(self, "_on_move_5_btn_click")
	if !%Move5Btn_L.button_down.is_connected(move_5_callable):
		%Move5Btn_L.button_down.connect(move_5_callable)
	if !%Move5Btn_R.button_down.is_connected(move_5_callable):
		%Move5Btn_R.button_down.connect(move_5_callable)
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
#endregion
