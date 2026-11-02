## Session-owned marker data, ready to be included in a future game save.
class_name RoadMarkerStore extends Resource

@export var markers: Array[RoadMarkerData] = []

func next_num() -> int:
	var next: int = 1
	for marker: RoadMarkerData in markers:
		next = maxi(next, marker.num + 1)
	return next

func get_by_num(num: int) -> RoadMarkerData:
	for marker: RoadMarkerData in markers:
		if marker.num == num:
			return marker
	return null
