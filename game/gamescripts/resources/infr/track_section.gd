class_name TrackSectionData extends Resource

@export var origin: RailNodeData:
	set(value):
		if !value: return
		origin = value
		self.track = value.parent_track

@export var target: RailNodeData

@export_storage var track: RailTrackData

static func of(_last: RailNodeData, _next: RailNodeData) -> TrackSectionData:
	var inst := TrackSectionData.new()
	inst.origin = _last
	inst.target = _next
	return inst
