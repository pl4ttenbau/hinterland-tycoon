class_name MapLongLat extends Resource

@export var topLeft: Array[float]
@export var bottomRight: Array[float]

var top: float:
	get(): return topLeft[0]

var left: float:
	get(): return topLeft[1]

var bottom: float:
	get(): return bottomRight[0]

var right: float:
	get(): return bottomRight[1]
