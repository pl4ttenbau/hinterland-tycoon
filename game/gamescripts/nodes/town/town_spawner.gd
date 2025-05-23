class_name TownSpawner extends Node

signal town_center_spawned(town: TownResource)

@export_storage var town: TownResource

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Loggie.info("Town spawner ready")

func _on_town_center_spawned(_town: TownResource) -> void:
	self.town = _town
	Loggie.info("town %s received" % _town)
