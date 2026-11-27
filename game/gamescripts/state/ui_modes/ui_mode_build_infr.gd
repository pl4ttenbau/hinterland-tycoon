class_name UiModeBuildInfr extends RefCounted

@export var key: Enums.UiMode = Enums.UiMode.BUILD_INFR

@export var at_fork: RailJunctionData

@export var infr_type: InfrType

static func from_fork(_fork: RailJunctionData) -> UiModeBuildInfr:
	var mode: UiModeBuildInfr = UiModeBuildInfr.new()
	mode.at_fork = _fork
	return mode
