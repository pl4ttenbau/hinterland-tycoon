class_name TownSpawner extends Node

@warning_ignore("unused_signal")
signal town_center_spawned(town: TownData)

@export_storage var town: TownData
@export var bld_count: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var town_res: TownData = (self.get_parent() as TownCenter).town
	self._on_town_center_spawned(town_res)
	
func spawn_rnd_building():
	var rnd_bld_type: ResBldType = GameTypes.get_rnd_res_bld()
	var scene_path: String = rnd_bld_type.get_scene_path()
	var instanciated: OuterResBld = load(scene_path).instantiate()
	instanciated.res_bld_type = rnd_bld_type
	# set random pos & rotation
	instanciated.position = get_rnd_pos()
	instanciated.rotate_y(randf_range(0, TAU))
	# assign num to increase counter
	self.register_spawned_building(instanciated)
	
func register_spawned_building(instanciated: OuterResBld):
	# assign new bld num
	instanciated.bld_num = OuterResBld.last_bld_num
	OuterResBld.last_bld_num += 1
	# add to city & global state array
	self.add_child(instanciated)
	GlobalState.res_bld_containers.append(instanciated)
	# increase counter
	self.bld_count += 1
	
#region Getters
func get_rnd_pos() -> Vector3: 
	var rnd_x: float = randf_range(self.town.pos_xz.x - 30, self.town.pos_xz.x + 30)
	var rnd_z: float = randf_range(self.town.pos_xz.y - 30, self.town.pos_xz.y + 30)
	return self.get_pos_at(Vector2(rnd_x, rnd_z))

func get_pos_at(pos_2d: Vector2) -> Vector3:
	var pos_3d: Vector3 = Vector3(pos_2d.x, 12, pos_2d.y)
	pos_3d.y = GlobalState.terrain.get_height_at(pos_3d)
	return pos_3d
#endregion

#region Callbacks
func _on_town_center_spawned(_town: TownData) -> void:
	self.town = _town
	for i: int in range(_town.get_initial_bld_count()):
		self.spawn_rnd_building()
	Loggie.info("Spawned town %s with %d buildings" % [_town.town_name, self.bld_count])
#endregion
