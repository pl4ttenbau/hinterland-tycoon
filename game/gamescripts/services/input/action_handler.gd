@icon("res://assets/icons/icon_input_white.png")
class_name ActionHandler extends Node

func _enter_tree() -> void:
	SignalBus.action_menu_triggered.connect(Callable(self, "_on_action_triggered"))
	
func _on_action_triggered(action_name: String) -> bool:
	if !action_name: return false
	for handler_child: Node in self.get_children():
		if handler_child is BaseAction:
			if handler_child.key == action_name:
				handler_child.on_trigger()
	# if action_name == "Enter":
	# 	$EnterAction.on_trigger()
	if action_name == "Spawn":
		$SpawnAction.on_trigger()
	elif action_name == "Connect":
		$ConnectAction.on_trigger()
	return true
