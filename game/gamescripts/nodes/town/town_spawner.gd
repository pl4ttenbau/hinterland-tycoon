class_name TownSpawner extends Node

@warning_ignore("unused_signal")
signal town_center_spawned(town: TownData)

@export_storage var town: TownData
@export var bld_count: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.town = (self.get_parent() as TownCenter).town
	self._on_town_center_spawned(self.town)
	
func spawn_rnd_building():
	var rnd_bld_type: ResBldType = GameTypes.get_rnd_res_bld()
	var scene_path: String = rnd_bld_type.get_scene_path()
	var instanciated: OuterResBld = load(scene_path).instantiate()
	# create & set res bld entity
	var res_bld_data: ResidenceBuildingData = ResidenceBuildingData.new(rnd_bld_type)
	res_bld_data.town_num = self.town.num
	instanciated.res_bld = res_bld_data
	# set random pos & rotation
	instanciated.position = get_checked_rnd_pos()
	instanciated.rotate_y(randf_range(0, TAU))
	# assign num to increase counter
	self.register_spawned_building(instanciated)
	
func register_spawned_building(outer_res_bld: OuterResBld):
	# add to city & global state array
	self.add_child(outer_res_bld)
	self.town.add_res_bld(outer_res_bld)
	# increase counter
	self.bld_count += 1
	
#region Getters
func get_rnd_pos() -> Vector3: 
	var rnd_x := randf_range(self.town.pos_xz.x - 30, self.town.pos_xz.x + 30)
	var rnd_z := randf_range(self.town.pos_xz.y - 30, self.town.pos_xz.y + 30)
	return self.get_pos_at(Vector2(rnd_x, rnd_z))
	
func get_checked_rnd_pos() -> Vector3:
	var tries_count: int = 0
	while tries_count <= 5:
		var unchecked_pos := self.get_rnd_pos()
		if  !self.town.has_bld_around(unchecked_pos):
			return unchecked_pos
		tries_count += 1
	return Vector3.ZERO

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
