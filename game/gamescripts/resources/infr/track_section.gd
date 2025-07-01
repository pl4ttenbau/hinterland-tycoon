class_name TrackSectionData extends Resource

@export var start: RailNodeData:
	set(value):
		if !value: return
		start = value
		self.track = value.parent_track

@export var end: RailNodeData
@export_storage var track: RailTrackData

static func of(_last: RailNodeData, _next: RailNodeData) -> TrackSectionData:
	var inst := TrackSectionData.new()
	inst.last_node = _last
	inst.next_node = _next
	inst.track = _last.parent_track
	return inst
