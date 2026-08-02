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
static func gps_coords_str_to_float_arr(gps_coords_str: String) -> Array[float]:
	var splitted: Array = gps_coords_str.split(",")
	if splitted == null || splitted.size() <= 1:
		Loggie.warn("Cant convert String \"%s\" to Float Array; return empty Array" % gps_coords_str)
		return []
	return [
		String(splitted[0]).replace(" ", "").to_float(),
		String(splitted[1]).replace(" ", "").to_float()
	]

static func gps_coords_to_map_pos(gps_coords: Array[float], map_pos_size: MapSizeAndPosData) -> Vector2i:
	var map_w_rad: float = map_pos_size.long_lat.top - map_pos_size.long_lat.left
	var map_h_rad: float = map_pos_size.long_lat.right - map_pos_size.long_lat.left
	# calculate X pos with longitude
	var longitude: float = gps_coords[1]
	var x_perc: float = (longitude - map_pos_size.long_lat.left) / map_w_rad
	var x_raster_no_offset: float = x_perc * map_pos_size.raster_width
	var x_raster: int = round(x_raster_no_offset + map_pos_size.raster_offset[0])
	# calculate Y pos with latitude
	var latitude: float = gps_coords[0]
	var y_perc: float = (latitude - map_pos_size.long_lat.bottom) / map_h_rad
	var y_raster_no_offset: float = map_pos_size.raster_height - (y_perc * map_pos_size.raster_height)
	var y_raster: int = round(y_raster_no_offset + map_pos_size.raster_offset[1])
	# return as float array
	return Vector2i(x_raster, y_raster)
#endregion
