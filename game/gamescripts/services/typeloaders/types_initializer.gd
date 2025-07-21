## Autoloaded
## hier wird das Laden von allen Typendatein getriggert
extends Node

func _init() -> void:
	# map object types
	InfrTypesLoader.new()
	IndustryTypeLoader.new()
	ResidentialBldTypeLoader.new()
	SignalBus.all_types_initialized.emit()
