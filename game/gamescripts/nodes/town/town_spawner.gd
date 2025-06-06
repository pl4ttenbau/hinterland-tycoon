class_name TownSpawner extends Node

@warning_ignore("unused_signal")
signal town_center_spawned(town: TownResource)

@export_storage var town: TownResource

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Loggie.info("Town spawner ready")
	var town: TownResource = (self.get_parent() as TownCenter).town
	self._on_town_center_spawned(town)
	
func spawn_rnd_building():
	Loggie.info(("SPAWN BLD"))
	var rnd_bld_type: ResBldType = ResBldTypeLoader.get_rnd()
	var scene_path: String = rnd_bld_type.get_scene_path()
	var scene: PackedScene = load(scene_path)
	var bld: Node3D = scene.instantiate()
	bld.position = get_rnd_pos()
	self.add_child(bld)
	
func get_rnd_pos() -> Vector3: 
	var rnd_x: int = randi_range(self.town.pos_xz.x - 30, self.town.pos_xz.x + 30)
	var rnd_z: int = randi_range(self.town.pos_xz.y - 30, self.town.pos_xz.y + 30)
	return self.get_pos_at(Vector2(rnd_x, rnd_z))

func get_pos_at(pos_2d: Vector2) -> Vector3:
	var pos_3d: Vector3 = Vector3(pos_2d.x, 12, pos_2d.y)
	var h: int = GlobalState.terrain.get_height_at(pos_3d)
	pos_3d.y = h
	return pos_3d

func _on_town_center_spawned(_town: TownResource) -> void:
	self.town = _town
	Loggie.info("town %s received" % _town)
	self.spawn_rnd_building()
	self.spawn_rnd_building()
	self.spawn_rnd_building()
