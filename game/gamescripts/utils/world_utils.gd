@tool
class_name WorldUtils extends RefCounted

const NINETY_DEG_IN_RAD = 1.57

#region FloatArr <> Vector3
static func vec3_from_float_arr(float_arr: Array):
	var vec3: Vector3 = Vector3()
	if (float_arr == null || typeof(float_arr) != TYPE_ARRAY):
		push_error("could not convert %s to Vector3" % float_arr)
		return
	vec3.x = float_arr[0]
	vec3.y = float_arr[1]
	vec3.z = float_arr[2]
	return vec3

static func float_arr_from_vec3(vec3: Vector3) -> Array[float]:
	var pos_arr: Array[float] = []
	# float rounding like in https://forum.godotengine.org/t/how-to-round-to-a-specific-decimal-place/27552/6
	pos_arr.append(snapped(vec3.x, 0.01)) # x
	pos_arr.append(snapped(vec3.y, 0.01)) # y
	pos_arr.append(snapped(vec3.z, 0.01)) # z
	return pos_arr
#endregion

## adds z height value according to map to Vector2 pos
static func pos_on_map(vec2: Vector2) -> Vector3:
	if GlobalState.world_container:
		var vec3 := Vector3(vec2.x, 0, vec2.y)
		return GlobalState.world_container.get_pos_at_height(vec3)
	return Vector3.ZERO

static func create_transform(pos: Vector3, rot: Vector3, scale: Vector3) -> Transform3D:
	var base: Basis = Basis.from_euler(rot)
	base.x *= scale.x
	base.y *= scale.y
	base.z *= scale.z
	return Transform3D(base, pos)

#region GPS Coords
## Parses decimal degrees in latitude, longitude order. Invalid input is empty.
static func gps_coords_str_to_float_arr(gps_coords_str: String) -> Array[float]:
	var parts: PackedStringArray = gps_coords_str.strip_edges().split(",", true)
	if parts.size() != 2:
		Loggie.warn("GPS coordinates must be decimal latitude, longitude")
		return []
	var coords: Array[float] = []
	for part: String in parts:
		var value: String = part.strip_edges()
		if not value.is_valid_float():
			Loggie.warn("GPS coordinates must contain two valid numbers")
			return []
		coords.append(value.to_float())
	if not is_finite(coords[0]) or not is_finite(coords[1]) \
			or absf(coords[0]) > 90.0 or absf(coords[1]) > 180.0:
		Loggie.warn("GPS coordinates are outside latitude/longitude limits")
		return []
	return coords

## Returns fractional heightmap sample coordinates, including rasterOffset.
## The two GPS corners identify the outer sample centres, so N samples have
## N-1 intervals. +X is east; +Y here becomes world +Z (south).
## Multiply by Terrain3D.vertex_spacing to get world-space coordinates.
## Invalid data or a point outside the map returns an infinite vector.
static func gps_coords_to_map_pos(gps_coords: Array[float], map_pos_size: MapSizeAndPosData) -> Vector2:
	var invalid := Vector2(INF, INF)
	if gps_coords.size() != 2:
		Loggie.warn("Cannot convert GPS position: missing coordinates or map metadata")
		return invalid
	var map_error: String = gps_map_validation_error(map_pos_size)
	if not map_error.is_empty():
		Loggie.warn("Cannot convert GPS position: %s" % map_error)
		return invalid
	var bounds: MapLongLat = map_pos_size.long_lat
	var north: float = bounds.top
	var south: float = bounds.bottom
	var west: float = bounds.left
	var east: float = bounds.right
	var latitude: float = gps_coords[0]
	var longitude: float = gps_coords[1]
	if not is_finite(latitude) or not is_finite(longitude) \
			or latitude < south or latitude > north or longitude < west or longitude > east:
		Loggie.warn("GPS position is outside this map's bounds")
		return invalid
	var x_fraction: float = (longitude - west) / (east - west)
	var z_fraction: float = (north - latitude) / (north - south)
	return Vector2(
		x_fraction * (map_pos_size.raster_width - 1.0) + map_pos_size.raster_offset[0],
		z_fraction * (map_pos_size.raster_height - 1.0) + map_pos_size.raster_offset[1]
	)

static func gps_map_validation_error(map_pos_size: MapSizeAndPosData) -> String:
	if map_pos_size == null or map_pos_size.long_lat == null:
		return "missing map metadata"
	var bounds: MapLongLat = map_pos_size.long_lat
	if bounds.topLeft.size() != 2 or bounds.bottomRight.size() != 2 \
			or map_pos_size.raster_size.size() != 2 or map_pos_size.raster_offset.size() != 2:
		return "incomplete map metadata"
	if not is_finite(bounds.top) or not is_finite(bounds.bottom) \
			or not is_finite(bounds.left) or not is_finite(bounds.right) \
			or bounds.top <= bounds.bottom or bounds.right <= bounds.left \
			or map_pos_size.raster_width < 2 or map_pos_size.raster_height < 2:
		return "invalid map bounds or raster size"
	return ""

## Returns decimal latitude and longitude from global X/Z, or an empty array
## if the map metadata is unusable or the point lies outside the raster.
static func world_pos_to_gps_coords(world_xz: Vector2, vertex_spacing: float, map_pos_size: MapSizeAndPosData) -> Array[float]:
	if not world_xz.is_finite() or not is_finite(vertex_spacing) or vertex_spacing <= 0.0 \
			or not gps_map_validation_error(map_pos_size).is_empty():
		return []
	# Convert both sample corners to world space the same way as GPS placement.
	# This keeps the rounded world positions of the boundary samples in bounds.
	var sample_x: int = map_pos_size.raster_offset[0]
	var sample_z: int = map_pos_size.raster_offset[1]
	var northwest := Vector2(sample_x, sample_z) * vertex_spacing
	var southeast := Vector2(
		sample_x + map_pos_size.raster_width - 1.0,
		sample_z + map_pos_size.raster_height - 1.0
	) * vertex_spacing
	if not northwest.is_finite() or not southeast.is_finite() \
			or southeast.x <= northwest.x or southeast.y <= northwest.y \
			or world_xz.x < northwest.x or world_xz.x > southeast.x \
			or world_xz.y < northwest.y or world_xz.y > southeast.y:
		return []
	var bounds: MapLongLat = map_pos_size.long_lat
	var x_fraction: float = inverse_lerp(northwest.x, southeast.x, world_xz.x)
	var z_fraction: float = inverse_lerp(northwest.y, southeast.y, world_xz.y)
	return [
		lerpf(bounds.top, bounds.bottom, z_fraction),
		lerpf(bounds.left, bounds.right, x_fraction)
	]
#endregion
