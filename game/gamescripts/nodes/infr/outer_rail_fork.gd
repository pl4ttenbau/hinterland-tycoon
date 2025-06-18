class_name OuterRailFork extends HideableObject

@export var fork: RailFork

static func of(_fork: RailFork) -> OuterRailFork:
	var inst := OuterRailFork.new()
	inst.fork = _fork
	return inst
