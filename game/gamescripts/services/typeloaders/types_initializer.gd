## Autoloaded
## hier wird das Laden von allen Typendatein getriggert
extends Node

@export_storage var industries: IndustryTypeLoader
@export_storage var infrastructure: InfrTypesLoader
@export_storage var residential_blds: ResidentialBldTypeLoader
@export_storage var resources: ResourceTypesLoader

func _init() -> void:
	# map object types
	ResourceTypesLoader.new()
	InfrTypesLoader.new()
	IndustryTypeLoader.new()
	ResidentialBldTypeLoader.new()
	SignalBus.all_types_initialized.emit()
