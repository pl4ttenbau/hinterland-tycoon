extends Node3D

@onready var terrain_container: TerrainContainer = %TerrainContainer
@onready var railPath: Path3D = %TestRailPath

func _ready() -> void:
	self.alignRailPath()
	Loggie.info("rail created")

func alignRailPath() -> void:
	for index in railPath.curve.point_count:
		var heightDiff: float = getRailPointHeightDiff2Terrain(index)
		var globalPos: Vector3 = getRailPathPointGlobalPos(index)
		var logStr = "%s (diff %.2f)" % [globalPos, heightDiff]
		Loggie.info(logStr)
		
func getRailPathPointGlobalPos(railPointIndex: int) -> Vector3:
	# for the abs point pos we need to add the offset from the TestRail node
	var localPos: Vector3 = railPath.curve.get_point_position(railPointIndex)
	return railPath.position + localPos
	
func getRailPointHeightDiff2Terrain(railPointIndex: int) -> float:
	var globalPos: Vector3 = getRailPathPointGlobalPos(railPointIndex)
	var terr_height: float = get_terrain_height_at(globalPos)
	return absf(globalPos.y - terr_height)

func get_terrain_height_at(pos3: Vector3) -> float:
	var terrain_3d: Terrain3D = self.terrain_container.terrain
	return terrain_3d.data.get_height(pos3)
