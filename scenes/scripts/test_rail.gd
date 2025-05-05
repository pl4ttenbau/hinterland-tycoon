extends Node3D

@onready var terrain: Terrain3D = %WorldTerrain
@onready var railPath: Path3D = %TestRailPath

func _ready() -> void:
	self.alignRailPath()
	print("rail created")

func alignRailPath() -> void:
	for index in railPath.curve.point_count:
		var heightDiff: float = getRailPointHeightDiff2Terrain(index)
		var globalPos: Vector3 = getRailPathPointGlobalPos(index)
		var logStr = "%s (diff %.2f)" % [globalPos, heightDiff]
		print(logStr)
		
func getRailPathPointGlobalPos(railPointIndex: int) -> Vector3:
	# for the abs point pos we need to add the offset from the TestRail node
	var localPos: Vector3 = railPath.curve.get_point_position(railPointIndex)
	return railPath.position + localPos
	
func getRailPointHeightDiff2Terrain(railPointIndex: int) -> float:
	var globalPos: Vector3 = getRailPathPointGlobalPos(railPointIndex)
	var terrHeight: float = terrain.data.get_height(globalPos)
	return absf(globalPos.y - terrHeight)
