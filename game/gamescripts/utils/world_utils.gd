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
	if gps_coords.size() != 2 or map_pos_size == null or map_pos_size.long_lat == null:
		Loggie.warn("Cannot convert GPS position: missing coordinates or map metadata")
		return invalid
	var bounds: MapLongLat = map_pos_size.long_lat
	if bounds.topLeft.size() != 2 or bounds.bottomRight.size() != 2 \
			or map_pos_size.raster_size.size() != 2 or map_pos_size.raster_offset.size() != 2:
		Loggie.warn("Cannot convert GPS position: incomplete map metadata")
		return invalid
	var north: float = bounds.top
	var south: float = bounds.bottom
	var west: float = bounds.left
	var east: float = bounds.right
	if not is_finite(north) or not is_finite(south) or not is_finite(west) or not is_finite(east) \
			or north <= south or east <= west \
			or map_pos_size.raster_width < 2 or map_pos_size.raster_height < 2:
		Loggie.warn("Cannot convert GPS position: invalid map bounds or raster size")
		return invalid
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
#endregion
