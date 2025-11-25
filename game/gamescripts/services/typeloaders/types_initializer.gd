## Autoloaded
## hier wird das Laden von allen Typendatein getriggert
@icon("res://assets/icons/icon_gears_white.png")
extends Node

@export_storage var industries: IndustryTypeLoader
@export_storage var infrastructure: InfrTypesLoader
@export_storage var res_bld_types: ResidentialBldTypeLoader
@export_storage var resources: GoodsTypesLoader

func _init() -> void:
	# map object types
	GoodsTypesLoader.new()
	InfrTypesLoader.new()
	IndustryTypeLoader.new()
	ResidentialBldTypeLoader.new()
	VehicleTypesLoader.new()
	SignalBus.all_types_initialized.emit()
