## Places block signals on rail tracks and shows each signal's aspect as a label until meshes exist.
class_name RailSignalTool extends Node

## The player must stand within this horizontal distance of the track centreline.
const MAX_PLACEMENT_DISTANCE: float = 4.0
## Removal picks the nearest signal within this distance of the player.
const MAX_REMOVAL_DISTANCE: float = 6.0
## Labels stand beside the track, on the right-hand side of the direction they apply to.
const LABEL_SIDE_OFFSET: float = 2.5
const LABEL_HEIGHT: float = 3.0
const REFRESH_SECONDS: float = 0.25
const COLOR_GO := Color("6fdc6f")
const COLOR_STOP := Color("ff5a4f")

var rails: RailsLoader
## {signal num: {direction: Label3D}}
var _labels: Dictionary = {}
var _views: Dictionary = {}
var _message: Label
var _since_refresh: float = 0.0

## Shared entry point for the circular menu; the location is captured before the dialog opens.
func open_placement_dialog() -> bool:
	if Managers.rails != rails or UiState.current_diag != null or not is_instance_valid(GlobalState.player):
		return false
	if GlobalState.player.control.is_in_vehicle():
		return false
	var player: BasicFpsPlayer = GlobalState.player.walking_body
	if not is_instance_valid(player):
		return false
	var camera: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3 = -camera.global_basis.z if camera != null else -player.global_basis.z
	var placement: Dictionary = placement_at(player.global_position, forward)
	if placement.is_empty():
		_show_message("Stand on a rail track to place a signal.")
		return false
	var script: GDScript = load("res://game/gamescripts/ui/dialogs/rail_signal/rail_signal_dialog.gd")
	get_tree().root.add_child(script.create(self, placement))
	return true

## The nearest track within reach. The default facing is the player's view direction along the track.
func placement_at(position: Vector3, forward: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = MAX_PLACEMENT_DISTANCE
	for track: RailTrackData in rails.track_storage.get_all():
		if track.curve == null or track.curve.point_count < 2:
			continue
		var local: Vector3 = _to_track_local(track, position)
		var offset: float = track.curve.get_closest_offset(local)
		var closest: Vector3 = track.curve.sample_baked(offset)
		var distance: float = Vector2(local.x - closest.x, local.z - closest.z).length()
		if distance > best_distance or absf(local.y - closest.y) > 3.0:
			continue
		best_distance = distance
		var length: float = track.curve.get_baked_length()
		var tangent: Vector3 = track.curve.sample_baked(minf(offset + 0.1, length)) - track.curve.sample_baked(maxf(offset - 0.1, 0.0))
		var facing: RailSignalData.Facing = RailSignalData.Facing.NODES_INCREASE
		if forward.dot(tangent) < 0.0:
			facing = RailSignalData.Facing.NODES_DECREASE
		best = {"track_num": track.num, "offset": offset, "facing": facing}
	return best

## Store a signal at the captured location and show its labels.
func place(placement: Dictionary, title: String, facing: RailSignalData.Facing) -> RailSignalData:
	## The track may have been erased while the dialog was open.
	var track: RailTrackData = rails.track_storage._by_id.get(placement.track_num)
	if track == null or track.curve == null or placement.offset < 0.0 or placement.offset > track.curve.get_baked_length():
		return null
	var rail_signal := RailSignalData.new()
	rail_signal.num = rails.signals.next_num()
	rail_signal.signal_name = title.strip_edges()
	if rail_signal.signal_name.is_empty():
		rail_signal.signal_name = "Signal %d" % rail_signal.num
	rail_signal.track_num = track.num
	rail_signal.offset = placement.offset
	rail_signal.facing = facing
	rails.signals.add(rail_signal)
	_show_signal(rail_signal, track)
	refresh_aspects()
	return rail_signal

#region Removal
## The circular menu offers removal only while a signal is within reach of the walking player.
func can_remove_near_player() -> bool:
	var player: BasicFpsPlayer = _walking_player()
	return player != null and nearest_signal(player.global_position) != null

## Remove the signal nearest to the walking player, from the circular menu.
func remove_near_player() -> bool:
	var player: BasicFpsPlayer = _walking_player()
	if player == null:
		return false
	var rail_signal: RailSignalData = nearest_signal(player.global_position)
	if rail_signal == null:
		_show_message("Stand next to a rail signal to remove it.")
		return false
	var title: String = rail_signal.signal_name
	if not remove(rail_signal):
		return false
	_show_message("Removed %s." % title)
	return true

## The nearest signal to a world position, measured to its point on the track centreline.
func nearest_signal(position: Vector3, max_distance: float = MAX_REMOVAL_DISTANCE) -> RailSignalData:
	var best: RailSignalData = null
	var best_distance: float = max_distance
	for rail_signal: RailSignalData in rails.signals.signals:
		var track: RailTrackData = rails.track_storage._by_id.get(rail_signal.track_num)
		if track == null or track.curve == null:
			continue
		var distance: float = _to_world(track, track.curve.sample_baked(rail_signal.offset)).distance_to(position)
		if distance <= best_distance:
			best_distance = distance
			best = rail_signal
	return best

## Drop the signal and its labels. Trains and other signals see the change on their next check.
func remove(rail_signal: RailSignalData) -> bool:
	if not rails.signals.remove(rail_signal):
		return false
	_labels.erase(rail_signal.num)
	var view: Node = _views.get(rail_signal.num)
	_views.erase(rail_signal.num)
	if is_instance_valid(view):
		## Detach now; queued deletion alone leaves the label visible until the frame ends.
		remove_child(view)
		view.queue_free()
	return true

func _walking_player() -> BasicFpsPlayer:
	if Managers.rails != rails or UiState.current_diag != null or not is_instance_valid(GlobalState.player):
		return null
	if GlobalState.player.control.is_in_vehicle():
		return null
	var player: BasicFpsPlayer = GlobalState.player.walking_body
	return player if is_instance_valid(player) else null
#endregion

func _process(delta: float) -> void:
	if _labels.is_empty():
		return
	_since_refresh += delta
	if _since_refresh < REFRESH_SECONDS:
		return
	_since_refresh = 0.0
	refresh_aspects()

## Recompute every signal's aspect from the current train positions and switch settings.
func refresh_aspects() -> void:
	var spans: Dictionary = RailSignalBlocks.occupancy(GlobalState.trains)
	for num: int in _labels:
		var rail_signal: RailSignalData = rails.signals.get_by_num(num)
		if rail_signal == null:
			continue
		for direction: Enums.PathDirection in _labels[num]:
			var clear: bool = RailSignalBlocks.is_block_clear(rail_signal, direction, rails.signals, spans)
			var label: Label3D = _labels[num][direction]
			label.text = "%s\n%s" % [rail_signal.signal_name, "GO" if clear else "STOP"]
			label.modulate = COLOR_GO if clear else COLOR_STOP

## One label per protected direction, on the right of a train travelling that way.
func _show_signal(rail_signal: RailSignalData, track: RailTrackData) -> void:
	var root := Node3D.new()
	root.name = "RailSignal_%d" % rail_signal.num
	add_child(root)
	var length: float = track.curve.get_baked_length()
	var center: Vector3 = _to_world(track, track.curve.sample_baked(rail_signal.offset))
	var increasing: Vector3 = _to_world(track, track.curve.sample_baked(minf(rail_signal.offset + 0.1, length))) \
		- _to_world(track, track.curve.sample_baked(maxf(rail_signal.offset - 0.1, 0.0)))
	increasing.y = 0.0
	increasing = increasing.normalized()
	root.global_position = center
	_labels[rail_signal.num] = {}
	for direction: Enums.PathDirection in rail_signal.get_directions():
		var travel: Vector3 = increasing if direction == Enums.PathDirection.TRACK_NODES_INCREASE else -increasing
		var right: Vector3 = travel.cross(Vector3.UP).normalized()
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.outline_size = 12
		label.pixel_size = 0.015
		label.position = right * LABEL_SIDE_OFFSET + Vector3.UP * LABEL_HEIGHT
		root.add_child(label)
		_labels[rail_signal.num][direction] = label
	_views[rail_signal.num] = root

## Track curves use the coordinates of their RailTrack3D path, when one is spawned.
func _to_world(track: RailTrackData, local: Vector3) -> Vector3:
	var path: Path3D = _track_path(track)
	return path.to_global(local) if path != null and path.is_inside_tree() else local

func _to_track_local(track: RailTrackData, world: Vector3) -> Vector3:
	var path: Path3D = _track_path(track)
	return path.to_local(world) if path != null and path.is_inside_tree() else world

func _track_path(track: RailTrackData) -> Path3D:
	var view: Node = rails.track_storage._containers_by_id.get(track.num)
	if not is_instance_valid(view) or view.get_child_count() == 0:
		return null
	return view.get_child(0) as Path3D

func _show_message(text: String) -> void:
	if not is_instance_valid(_message):
		var canvas := CanvasLayer.new()
		add_child(canvas)
		_message = Label.new()
		_message.position = Vector2(24, 80)
		canvas.add_child(_message)
	_message.text = text
	_message.show()
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(_message): _message.hide())
