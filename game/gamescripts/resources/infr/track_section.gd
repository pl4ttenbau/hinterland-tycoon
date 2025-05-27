class_name TrackSection extends Resource

@export var last_node: RailNode
@export var next_node: RailNode
@export_storage var track: RailTrack

static func of(_last: RailNode, _next: RailNode) -> TrackSection:
	var instance: TrackSection = TrackSection.new()
	instance.last_node = _last
	instance.next_node = _next
	instance.track = _last.parent_track
	return instance

# == SETTERS ==
func set_last(_last: RailNode) -> void:
	if !_last: return
	self.last_node = _last
	if _last.parent_track:
		self.track = _last.parent_track
		
func set_next(_next: RailNode) -> void:
	self.next_node = _next
