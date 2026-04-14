@tool
class_name TransferInventoryRowUi extends PanelContainer

signal side_switched(is_left: bool)

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
	if !self.side_switched.connect(side_switched_callable):
		self.side_switched.connect(side_switched_callable)

func hide_left_right():
	Loggie.info("hidng")
	%MoveLeftContainer.visible = !self.is_left
	%MoveRightContainer.visible = self.is_left
#endregion

#region Callables

#endregion
