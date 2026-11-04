## Per-layer terrain eligibility and coverage. Grass and crops use separate resources.
@tool
class_name GrassAreaDefinition
extends Resource

@export var description: String
## Terrain3D IDs for light/dark and optionally patchy/dry grass on this map.
@export var terrain_texture_ids: PackedInt32Array = PackedInt32Array([0])
## Optional linear-data mask: white allows grass, black removes it, gray thins it.
## Roads, tracks, buildings and other footprints can all subtract from this layer.
@export var coverage_mask: Texture2D
## World X/Z bounds of the mask. An empty rectangle uses the full terrain bounds.
@export var mask_bounds: Rect2
## Baked full-area images already contain terrain eligibility; avoid applying it twice.
@export var coverage_includes_terrain: bool = false
## Written by the baker; empty crop maps can avoid allocating any particles.
@export var coverage_is_empty: bool = false

@export_group("Bake")
@export_range(256, 8192, 256) var bake_resolution: int = 4096
## Clear distance beyond the road/ballast source-mesh footprint, in metres.
@export_range(0.0, 8.0, 0.1) var infrastructure_clearance: float = 1.5
@export_range(0.0, 8.0, 0.1) var edge_feather: float = 1.5
## Ignore elevated bridges and buried tunnels beyond this vertical distance.
@export_range(0.25, 10.0, 0.25) var maximum_surface_height_difference: float = 3.0

func get_texture_mask() -> int:
	var mask: int = 0
	for id: int in terrain_texture_ids:
		if id >= 0 and id < 32:
			mask |= 1 << id
	return mask
