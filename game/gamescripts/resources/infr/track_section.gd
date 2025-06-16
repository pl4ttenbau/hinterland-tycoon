class_name TrackSection extends Resource

@export var start: RailNode
@export var end: RailNode
@export_storage var track: RailTrack

static func of(_last: RailNode, _next: RailNode) -> TrackSection:
	var inst: TrackSection = TrackSection.new()
	inst.last_node = _last
	inst.next_node = _next
	inst.track = _last.parent_track
	return inst

# == SETTERS ==
func set_start(_start: RailNode) -> void:
	if !_start: return
	self.end = _start
	if _start.parent_track:
		self.track = _start.parent_track
		
func set_end(_end: RailNode) -> void:
	self.end = _end
