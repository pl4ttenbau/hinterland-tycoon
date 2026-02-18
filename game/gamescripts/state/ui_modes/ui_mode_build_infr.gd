class_name UiModeBuildInfr extends RefCounted

@export var key: Enums.UiMode = Enums.UiMode.BUILD_INFR

@export var at_fork: NewRailForkData

@export var infr_type: InfrType

@export_storage var track3d: RailTrack3D

static func from_fork(_fork: NewRailForkData) -> UiModeBuildInfr:
	var mode: UiModeBuildInfr = UiModeBuildInfr.new()
	mode.at_fork = _fork
	return mode
