class_name ActionHandler extends Node

func _enter_tree() -> void:
	SignalBus.action_menu_triggered.connect(Callable(self, "_on_action_triggered"))
	
func _on_action_triggered(item: ActionMenuItem) -> bool:
	Loggie.info("Action Selected: %s" % item.get_action_name())
	return true
