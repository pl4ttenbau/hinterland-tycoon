class_name MapSizeAndPosData extends Resource

@export var long_lat: MapLongLat

@export var raster_size: Array[int]
@export var raster_offset: Array[int]

var raster_width: float: 
	get(): return raster_size[0]

var raster_height: float:
	get(): return raster_size[1]

#region Convert From Dict
static func of_dict(size_and_pos_dict: Dictionary) -> MapSizeAndPosData:
	var inst: MapSizeAndPosData = MapSizeAndPosData.new()
	# longLat
	if size_and_pos_dict.has("longLat"):
		var longLatDict: Dictionary = size_and_pos_dict.get("longLat")
		var longLatDto: MapLongLat = MapLongLat.new()
		longLatDto.topLeft = arr_to_2_float_arr(longLatDict.get("topLeft"))
		longLatDto.bottomRight = arr_to_2_float_arr(longLatDict.get("bottomRight"))
		inst.long_lat = longLatDto
	# rasterSize
	if size_and_pos_dict.has("rasterSize"):
		inst.raster_size = arr_to_2_int_arr(size_and_pos_dict.get("rasterSize"))
	# rasterOffset
	if size_and_pos_dict.has("rasterOffset"):
		inst.raster_offset = arr_to_2_int_arr(size_and_pos_dict.get("rasterOffset"))
	return inst
#endregion

#region Typed Array Conversion
static func arr_to_2_float_arr(any_arr: Array) -> Array[float]:
	return [
		any_arr[0] as float,
		any_arr[1] as float
	]

static func arr_to_2_int_arr(any_arr: Array) -> Array[int]:
	return [
		any_arr[0] as int,
		any_arr[1] as int
	]
#endregion
