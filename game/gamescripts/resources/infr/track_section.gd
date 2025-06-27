class_name TrackSectionData extends Resource

@export var start: RailNodeData
@export var end: RailNodeData
@export_storage var track: RailTrackData

static func of(_last: RailNodeData, _next: RailNodeData) -> TrackSectionData:
	var inst := TrackSectionData.new()
	inst.last_node = _last
	inst.next_node = _next
	inst.track = _last.parent_track
	return inst

# == SETTERS ==
func set_start(_start: RailNodeData) -> void:
	if !_start: return
	self.end = _start
	if _start.parent_track:
		self.track = _start.parent_track
		
func set_end(_end: RailNodeData) -> void:
	self.end = _end
