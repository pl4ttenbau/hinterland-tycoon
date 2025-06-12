extends Node

func _init() -> void:
	InfrTypesLoader.new()
	IndustryTypeLoader.new()
	ResidentialBldTypeLoader.new()
	SignalBus.all_types_initialized.emit()
