class_name MineralGeology extends RefCounted

const PAINTED_RICHNESS_FLOOR: float = 0.50
const COMMON_STONE_FLOOR: float = 0.12
const PAINTED_RESOURCES: Dictionary[String, String] = {
	"rock": "stone",
	"stone": "stone",
	"gravel": "gravel",
}
# Frequency sets the scale of the pockets. Occurrence scales the richness independently.
const OCCURRENCE: Dictionary[String, float] = {
	"stone": 1.0,
	"gravel": 0.90,
	"coal": 0.82,
	"ore": 0.74,
}

var _fields: Dictionary[String, FastNoiseLite] = {}


func _init(map_seed: int) -> void:
	# Keep the seed offsets stable so the same map key keeps its deposits in the same places.
	_fields["stone"] = _make_field(map_seed, 0.003)
	_fields["gravel"] = _make_field(map_seed + 1, 0.004)
	_fields["coal"] = _make_field(map_seed + 2, 0.006)
	_fields["ore"] = _make_field(map_seed + 3, 0.007)


## Returns independent richness values from 0 to 1, using the existing cargo keys.
func sample(
	world_position: Vector3,
	terrain_data: Terrain3DData = null,
	terrain_assets: Terrain3DAssets = null,
) -> Dictionary[String, float]:
	var richness: Dictionary[String, float] = {}
	for resource: String in _fields:
		var normalized: float = clampf(
			_fields[resource].get_noise_2d(world_position.x, world_position.z) * 0.5 + 0.5,
			0.0,
			1.0,
		)
		var concentration: float = normalized * normalized
		# Keep weak signals as traces and concentrate useful coal and iron in the peaks.
		if resource == "coal" or resource == "ore":
			concentration *= concentration
		richness[resource] = concentration * OCCURRENCE[resource]
	richness["stone"] = maxf(richness["stone"], COMMON_STONE_FLOOR)

	if terrain_data != null and terrain_assets != null:
		_apply_terrain_paint(richness, terrain_data, terrain_assets, world_position)
	return richness


static func _apply_terrain_paint(
	richness: Dictionary[String, float],
	data: Terrain3DData,
	assets: Terrain3DAssets,
	world_position: Vector3,
) -> void:
	if not data.has_regionp(world_position) or data.get_control_hole(world_position):
		return
	# Only explicit terrain paint carries authored deposit clues.
	if data.get_control_auto(world_position):
		return

	var base_resource: String = _painted_resource(assets, data.get_control_base_id(world_position))
	var overlay_resource: String = _painted_resource(assets, data.get_control_overlay_id(world_position))
	var blend: float = data.get_control_blend(world_position)
	# Blend is the overlay's share. Matching base and overlay resources cover the whole point.
	if not base_resource.is_empty():
		var coverage: float = 1.0 if base_resource == overlay_resource else 1.0 - blend
		richness[base_resource] = maxf(richness[base_resource], PAINTED_RICHNESS_FLOOR * coverage)
	if not overlay_resource.is_empty() and overlay_resource != base_resource:
		richness[overlay_resource] = maxf(richness[overlay_resource], PAINTED_RICHNESS_FLOOR * blend)


static func _painted_resource(assets: Terrain3DAssets, texture_id: int) -> String:
	if texture_id < 0 or texture_id >= assets.texture_list.size():
		return ""
	var texture: Terrain3DTextureAsset = assets.get_texture_asset(texture_id)
	if texture == null:
		return ""
	return PAINTED_RESOURCES.get(texture.get_name().strip_edges().to_lower(), "")


static func _make_field(seed_value: int, frequency: float) -> FastNoiseLite:
	var field := FastNoiseLite.new()
	field.seed = seed_value & 0x7fffffff
	field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	field.frequency = frequency
	field.fractal_type = FastNoiseLite.FRACTAL_FBM
	field.fractal_octaves = 2
	return field
