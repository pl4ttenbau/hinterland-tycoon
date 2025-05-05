extends Node

func vec3_from_float_arr(float_arr: Array):
	var vec3: Vector3 = Vector3()
	if (float_arr == null || typeof(float_arr) != TYPE_ARRAY):
		push_error("could not convert %s to Vector3" % float_arr)
		return
	vec3.x = float_arr[0]
	vec3.y = float_arr[1]
	vec3.z = float_arr[2]
	return vec3	
