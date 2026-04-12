class_name WorldUtils extends RefCounted

const NINETY_DEG_IN_RAD = 1.57

static func vec3_from_float_arr(float_arr: Array):
	var vec3: Vector3 = Vector3()
	if (float_arr == null || typeof(float_arr) != TYPE_ARRAY):
		push_error("could not convert %s to Vector3" % float_arr)
		return
	vec3.x = float_arr[0]
	vec3.y = float_arr[1]
	vec3.z = float_arr[2]
	return vec3	

static func pos_on_map(vec2: Vector2) -> Vector3:
	if GlobalState.world_container:
		var vec3 := Vector3(vec2.x, 0, vec2.y)
		return GlobalState.world_container.get_pos_at_height(vec3)
	return Vector3.ZERO
