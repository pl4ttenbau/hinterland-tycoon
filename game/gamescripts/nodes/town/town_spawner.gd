@icon("res://assets/icons/icon_town_white.png")
class_name TownSpawner extends Node

@warning_ignore("unused_signal")
signal town_center_spawned(town: TownData)

@export_storage var town: TownData
@export var bld_count: int = 0

# Loading Flags
@export var has_spawned_self: bool = false
@export var has_bld_types_loaded: bool = false

const MAX_PLACING_TRIES: int = 6

#region Initialization
func _enter_tree() -> void:
	SignalBus.res_bld_types_loaded.connect(Callable(self, "_on_res_bld_types_loaded"))
func _ready() -> void:
	self.town = (self.get_parent() as TownCenter).town
	self._on_town_center_spawned(self.town)
#endregion

#region Town Building Spawning
func spawn_rnd_buildings():
	pass
	#if self.town.autogenerate_houses == false: return
	#for i: int in range(self.town.get_initial_bld_count()):
	#	self.spawn_single_rnd_building()
	#self.town.reassign_buildings_to_stations()

func spawn_single_rnd_building():
	if !self.has_bld_types_loaded || !self.has_spawned_self: return
	var rnd_bld_type: ResBldType = GameTypes.get_rnd_placable_res_bld()
	var packed_scene: PackedScene = load(rnd_bld_type.get_scene_path())
	var instanciated: OuterResBld = packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	# create & set res bld entity
	instanciated.res_bld = ResidenceBuildingData.new(self.town.num, rnd_bld_type)
	# set random pos & rotation
	instanciated.position = get_checked_rnd_pos()
	instanciated.rotate_y(randf_range(0, TAU))
	# assign num to increase counter
	self.register_spawned_building(instanciated)
#endregion

#region Helper-Methods
func register_spawned_building(outer_res_bld: OuterResBld):
	# add to city & global state array
	self.add_child(outer_res_bld)
	self.town.add_res_bld(outer_res_bld)
	outer_res_bld.res_bld_obj.is_registered = true
	# increase counter
	self.bld_count += 1
#endregion
	
#region Getters
func get_rnd_pos() -> Vector3: 
	var rnd_x := randf_range(self.town.pos_xz.x - 30, self.town.pos_xz.x + 30)
	var rnd_z := randf_range(self.town.pos_xz.y - 30, self.town.pos_xz.y + 30)
	return self.get_pos_at(Vector2(rnd_x, rnd_z))
	
func get_checked_rnd_pos() -> Vector3:
	for try_count: int in range (MAX_PLACING_TRIES):
		var unchecked_pos := self.get_rnd_pos()
		if  !self.town.has_bld_around(unchecked_pos):
			return unchecked_pos
	return Vector3.ZERO

func get_pos_at(pos_2d: Vector2) -> Vector3:
	var pos_3d: Vector3 = Vector3(pos_2d.x, -1, pos_2d.y)
	pos_3d.y = GlobalState.world_container.get_height_at(pos_3d)
	return pos_3d
#endregion

#region Callbacks
func _on_town_center_spawned(_town: TownData) -> void:
	self.has_spawned_self = true
	self.spawn_rnd_buildings()
	
func _on_res_bld_types_loaded():
	self.has_bld_types_loaded = true
	self.spawn_rnd_buildings()
#endregion
