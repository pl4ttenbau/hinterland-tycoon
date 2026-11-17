## Session-owned rail signals, ready to be included in a future game save.
class_name RailSignalStore extends Resource

@export var signals: Array[RailSignalData] = []

func next_num() -> int:
	var next: int = 1
	for rail_signal: RailSignalData in self.signals:
		next = maxi(next, rail_signal.num + 1)
	return next

func add(rail_signal: RailSignalData) -> void:
	self.signals.append(rail_signal)

func get_by_num(num: int) -> RailSignalData:
	for rail_signal: RailSignalData in self.signals:
		if rail_signal.num == num:
			return rail_signal
	return null

func get_on_track(track_num: int) -> Array[RailSignalData]:
	var found: Array[RailSignalData] = []
	for rail_signal: RailSignalData in self.signals:
		if rail_signal.track_num == track_num:
			found.append(rail_signal)
	return found
