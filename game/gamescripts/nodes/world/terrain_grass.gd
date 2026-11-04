## Near-camera grass using Terrain3D's GPU particle placement technique.
## Tiles are recycled only at cell boundaries; world-coordinate randomness stays fixed.
## Editor previews use the same bounded population without saving generated tiles.
@tool
extends Node3D

const PLACEMENT: Shader = preload("res://assets/packed/grass_particles.gdshader")
const GrassAreas = preload("res://game/gamescripts/resources/terrain/grass_area_definition.gd")
const CELL_SIZE: float = 16.0
const MAX_WATER_PLANES: int = 32

@export var terrain: Terrain3D
## Leave empty for the six-triangle crossed cards; accepts a replacement mesh.
@export var grass_mesh: Mesh
@export var grass_material: ShaderMaterial = preload("res://assets/packed/grass_material.tres")
## Frees all grass particles when disabled. Can be changed during play.
@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			rebuild()
## Spacing controls the actual GPU population. Call rebuild() after changing it at runtime.
@export_range(0.75, 2.0, 0.125) var instance_spacing: float = 1.0
## Fraction of candidates retained; reducing spacing is more costly than raising this.
@export_range(0.0, 1.0, 0.05) var density: float = 0.75
## Range is capped by tile coverage. Call rebuild() after changing these settings.
@export_range(4.0, 16.0, 1.0) var draw_distance: float = 16.0
@export_range(2.0, 14.0, 1.0) var fade_start: float = 10.0
## Map-specific terrain eligibility and optional general grass coverage mask.
@export var grass_areas: GrassAreas = preload("res://world/default/vegetation/grass_areas.tres")
@export_range(0.5, 1.0, 0.01) var minimum_normal_y: float = 0.85
## Stop drawing from overhead/map cameras. Uses full 3D distance in the draw shader too.
@export_range(8.0, 64.0, 1.0) var maximum_camera_height: float = 24.0

var particle_count: int = 0
var _tiles: Dictionary[Vector2i, GPUParticles3D] = {}
var _process_material: ShaderMaterial
var _draw_material: ShaderMaterial
var _mesh: Mesh
var _rows: int
var _cell: Vector2i = Vector2i(2147483647, 2147483647)
var _editor_preview_enabled: bool = true
var _editor_refresh_delay: float = 0.0
var _editor_data: Terrain3DData

func _ready() -> void:
	if not terrain:
		terrain = get_parent() as Terrain3D
	add_to_group(&"_terrain_vegetation")
	rebuild()

func get_vegetation_layer() -> StringName:
	return &"grass"

## Preview state is transient; never changes the saved runtime enabled flag.
func set_editor_preview_enabled(value: bool) -> void:
	if not Engine.is_editor_hint() or _editor_preview_enabled == value:
		return
	_editor_preview_enabled = value
	if is_node_ready():
		rebuild()

func _can_draw() -> bool:
	return enabled and (not Engine.is_editor_hint() or _editor_preview_enabled) \
		and grass_areas != null and grass_areas.get_texture_mask() != 0 and not grass_areas.coverage_is_empty

func _bind_editor_data() -> void:
	if not Engine.is_editor_hint() or not is_instance_valid(terrain) or terrain.data == _editor_data:
		return
	_disconnect_editor_data()
	_editor_data = terrain.data
	if is_instance_valid(_editor_data):
		_editor_data.maps_changed.connect(_queue_editor_rebuild)
		_editor_data.maps_edited.connect(_on_editor_terrain_edited)

func _disconnect_editor_data() -> void:
	if is_instance_valid(_editor_data):
		_editor_data.maps_changed.disconnect(_queue_editor_rebuild)
		_editor_data.maps_edited.disconnect(_on_editor_terrain_edited)
	_editor_data = null

func _queue_editor_rebuild() -> void:
	# Debounce brush strokes and map uploads instead of rebuilding every frame.
	_editor_refresh_delay = 0.25

func _on_editor_terrain_edited(_area: AABB) -> void:
	_queue_editor_rebuild()

func _exit_tree() -> void:
	_disconnect_editor_data()

## Recreates the bounded population and refreshes terrain maps, masks and water planes.
func rebuild() -> void:
	_clear_tiles()
	_process_material = null
	_draw_material = null
	_mesh = null
	_bind_editor_data()
	set_process(_can_draw() and is_instance_valid(terrain))
	if not _can_draw() or not is_instance_valid(terrain) or not terrain.data:
		return
	if Engine.is_editor_hint() and terrain.data.get_region_locations().is_empty():
		return
	_rows = maxi(1, int(CELL_SIZE / clampf(instance_spacing, 0.75, 2.0)))
	# Divide exactly into the cell so adjacent tiles never leave seams or overlap.
	var spacing: float = CELL_SIZE / float(_rows)
	_mesh = grass_mesh if grass_mesh else _make_crossed_cards()
	_process_material = ShaderMaterial.new()
	_process_material.shader = PLACEMENT
	var params: Dictionary = {
		"instance_rows": _rows, "instance_spacing": spacing,
		"density": clampf(density, 0.0, 1.0), "minimum_normal_y": minimum_normal_y,
		"_vertex_spacing": terrain.vertex_spacing, "_region_size": terrain.region_size,
		"_region_map": terrain.data.get_region_map(),
	}
	params["grass_texture_mask"] = grass_areas.get_texture_mask() if grass_areas else 0
	for param: String in params:
		_process_material.set_shader_parameter(param, params[param])
	var rid: RID = _process_material.get_rid()
	RenderingServer.material_set_param(rid, "_height_maps", terrain.data.get_height_maps_rid())
	RenderingServer.material_set_param(rid, "_control_maps", terrain.data.get_control_maps_rid())
	RenderingServer.material_set_param(rid, "_color_maps", terrain.data.get_color_maps_rid())
	_set_grass_area_mask()
	_set_water_masks()
	_draw_material = grass_material.duplicate() as ShaderMaterial
	_draw_material.set_shader_parameter("draw_distance", clampf(draw_distance, 4.0, CELL_SIZE))
	_draw_material.set_shader_parameter("fade_start", clampf(fade_start, 0.0, draw_distance - 1.0))

func _set_grass_area_mask() -> void:
	var has_mask: bool = grass_areas != null and grass_areas.coverage_mask != null
	_process_material.set_shader_parameter("grass_area_mask_enabled", has_mask)
	_process_material.set_shader_parameter("grass_area_includes_terrain", has_mask and grass_areas.coverage_includes_terrain)
	if not has_mask:
		return
	var bounds: Rect2 = grass_areas.mask_bounds
	if not bounds.has_area():
		var locations: Array[Vector2i] = terrain.data.get_region_locations()
		if locations.is_empty():
			# No terrain exists to support grass yet. Keep UV division well defined.
			bounds = Rect2(Vector2.ZERO, Vector2.ONE)
		else:
			var minimum: Vector2i = locations[0]
			var maximum: Vector2i = locations[0]
			for location: Vector2i in locations:
				minimum = Vector2i(mini(minimum.x, location.x), mini(minimum.y, location.y))
				maximum = Vector2i(maxi(maximum.x, location.x), maxi(maximum.y, location.y))
			var size_metres: float = terrain.region_size * terrain.vertex_spacing
			bounds = Rect2(Vector2(minimum) * size_metres,
				Vector2(maximum - minimum + Vector2i.ONE) * size_metres)
	_process_material.set_shader_parameter("grass_area_mask", grass_areas.coverage_mask)
	_process_material.set_shader_parameter("grass_area_origin", bounds.position)
	_process_material.set_shader_parameter("grass_area_size", bounds.size)


func _make_crossed_cards() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Three upright, intersecting cards. Upward normals give coherent meadow lighting.
	var corners: Array[Vector3] = [Vector3(-0.75, 0, 0), Vector3(-0.75, 1, 0),
		Vector3(0.75, 1, 0), Vector3(0.75, 0, 0)]
	var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
	for card: int in range(3):
		var rotation := Basis(Vector3.UP, float(card) * PI / 3.0)
		for index: int in [0, 1, 2, 0, 2, 3]:
			builder.set_color(Color.WHITE)
			builder.set_normal(Vector3.UP)
			builder.set_uv(uvs[index])
			builder.add_vertex(rotation * corners[index])
	return builder.commit()

func _process(delta: float) -> void:
	if not is_instance_valid(terrain) or not terrain.data:
		return
	if Engine.is_editor_hint():
		var scene: Node = EditorInterface.get_edited_scene_root()
		if not is_instance_valid(scene) or (scene != self and not scene.is_ancestor_of(self)):
			for tile: GPUParticles3D in _tiles.values():
				tile.visible = false
			return
		if _editor_refresh_delay > 0.0:
			_editor_refresh_delay -= delta
			if _editor_refresh_delay <= 0.0:
				rebuild()
		if not _process_material:
			if _editor_refresh_delay <= 0.0:
				_queue_editor_rebuild()
			return
	if not _process_material:
		return
	var camera: Camera3D = EditorInterface.get_editor_viewport_3d(0).get_camera_3d() \
		if Engine.is_editor_hint() else terrain.get_camera()
	if not is_instance_valid(camera):
		return
	var pos: Vector3 = camera.global_position
	var ground_height: float = terrain.data.get_height(pos)
	var near_ground: bool = is_finite(ground_height) and absf(pos.y - ground_height) < maximum_camera_height
	for tile: GPUParticles3D in _tiles.values():
		tile.visible = near_ground
	if not near_ground:
		return
	var cell := Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))
	if cell != _cell:
		_update_tiles(cell)

func _update_tiles(cell: Vector2i) -> void:
	var wanted: Array[Vector2i] = []
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			wanted.append(cell + Vector2i(x, z))
	var spare: Array[GPUParticles3D] = []
	for key: Vector2i in _tiles.keys():
		if not wanted.has(key):
			spare.append(_tiles[key])
			_tiles.erase(key)
	for key: Vector2i in wanted:
		if _tiles.has(key):
			continue
		var tile: GPUParticles3D = spare.pop_back() if not spare.is_empty() else _make_tile()
		tile.global_position = Vector3(key.x * CELL_SIZE, 0.0, key.y * CELL_SIZE)
		tile.reset_physics_interpolation()
		tile.restart(true)
		_tiles[key] = tile
	_cell = cell
	particle_count = _tiles.size() * _rows * _rows

func _make_tile() -> GPUParticles3D:
	var tile := GPUParticles3D.new()
	tile.amount = _rows * _rows
	tile.lifetime = 3600.0
	tile.explosiveness = 1.0
	tile.fixed_fps = 10
	tile.preprocess = 0.1
	tile.use_fixed_seed = true
	tile.seed = 1
	tile.process_material = _process_material
	tile.draw_pass_1 = _mesh
	tile.material_override = _draw_material
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.layers = 128 # Foliage
	var heights: Vector2 = terrain.data.get_height_range()
	# Terrain3D returns (minimum, maximum). Include blade and wind margins.
	tile.custom_aabb = AABB(Vector3(-1.0, heights.x - 1.0, -1.0),
		Vector3(CELL_SIZE + 2.0, maxf(heights.y - heights.x + 3.0, 3.0), CELL_SIZE + 2.0))
	add_child(tile)
	return tile

func _set_water_masks() -> void:
	var inverses: Array[Transform3D] = []
	var limits: PackedVector4Array = []
	# Current maps represent water surfaces with horizontal PlaneMesh nodes.
	for node: Node in terrain.find_children("*", "MeshInstance3D", true, false):
		var surface := node as MeshInstance3D
		if not surface.mesh is PlaneMesh:
			continue
		if absf(surface.global_basis.y.normalized().dot(Vector3.UP)) < 0.99:
			continue
		if inverses.size() == MAX_WATER_PLANES:
			push_warning("Grass: water plane mask limit reached")
			break
		var size: Vector2 = (surface.mesh as PlaneMesh).size * 0.5
		inverses.append(surface.global_transform.affine_inverse())
		limits.append(Vector4(size.x, size.y, surface.global_position.y + 0.15, 0.0))
	_process_material.set_shader_parameter("water_count", inverses.size())
	# Shader uniform arrays have a fixed size, including on maps without water.
	while inverses.size() < MAX_WATER_PLANES:
		inverses.append(Transform3D.IDENTITY)
		limits.append(Vector4.ZERO)
	_process_material.set_shader_parameter("water_inverse", inverses)
	_process_material.set_shader_parameter("water_limits", limits)

func _clear_tiles() -> void:
	for tile: GPUParticles3D in _tiles.values():
		tile.emitting = false
		tile.queue_free()
	_tiles.clear()
	particle_count = 0
	_cell = Vector2i(2147483647, 2147483647)
