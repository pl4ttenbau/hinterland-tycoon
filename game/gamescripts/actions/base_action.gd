@abstract
class_name BaseAction extends Node

@export var key: String

func on_trigger(): 
	var classname: String = self.get_class()
	Loggie.info("Action Menu Triggered: [%s]" % classname)
