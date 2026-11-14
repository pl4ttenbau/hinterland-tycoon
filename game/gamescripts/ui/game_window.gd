@warning_ignore("missing_tool")
@icon("res://assets/icons/icon_play_ui.png")
class_name GameWindow extends Control

var _company: CompanyData

@onready var _cash_panel: PanelContainer = $OuterBottomBar/ButtomBarLaybout/CashPanel
@onready var _cash_label: Label = _cash_panel.get_node("Margin/Cash")

#region Initialization
func _enter_tree() -> void:
	SignalBus.map_spawned.connect(Callable(self, "_on_scene_spawned"))


func _ready() -> void:
	_company = CompanyData.current()
	_cash_panel.visible = _company != null
	if _company != null:
		_company.changed.connect(_update_cash)
		_update_cash()


func _update_cash() -> void:
	_cash_label.text = "Cash  %s" % CompanyData.format_cash(_company.cash)
#endregion

#region Callbacks
func _on_scene_spawned(_container: WorldMapScene):
	self.visible = true
#endregion
